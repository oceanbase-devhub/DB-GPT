# Configurations for user
LLM_PROXY_SERVER_URL="https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
EMBED_PROXY_URL="https://dashscope.aliyuncs.com/api/v1/services/embeddings/text-embedding/text-embedding"

CONFIG_FILE="./config.sh"
source "$CONFIG_FILE"

TMP_FILE=$(mktemp)

# 设置文本颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    local type=$1
    local message=$2
    case $type in
    "info")
        printf "${BLUE}$message${NC}"
        ;;
    "success")
        printf "${GREEN}$message${NC}"
        ;;
    "error")
        printf "${RED}$message${NC}"
        ;;
    *)
        printf "${BLUE}$message${NC}"
        ;;
    esac
}

update_env_var() {
    local var_name=$1
    local comment=$2
    local current_value=${!var_name}

    # 提示用户输入新的值
    read -p "$(printf $BLUE"${comment}（回车以保持当前值: ${current_value}）: "$NC)" new_value

    # 如果用户输入了新的值，则更新环境变量
    if [ -n "$new_value" ]; then
        export $var_name="$new_value"
        printf "$var_name=\"$new_value\"\n" >> "$TMP_FILE"
    else
        export $var_name="$current_value"
        printf "$var_name=\"$current_value\"\n" >> "$TMP_FILE"
    fi
}

update_env_var "DBGPT_TONGYI_API_KEY" "设置通义API KEY"
update_env_var "DBGPT_OB_HOST" "设置OceanBase数据库主机地址"
update_env_var "DBGPT_OB_PORT" "设置OceanBase数据库端口"
update_env_var "DBGPT_OB_USER" "设置OceanBase数据库用户名（或者用户名@租户名）"
update_env_var "DBGPT_OB_PASSWORD" "设置OceanBase数据库密码"
update_env_var "DBGPT_OB_DATABASE" "设置OceanBase数据库名"
mv "$TMP_FILE" "$CONFIG_FILE"

resp=$(curl -s --location "$EMBED_PROXY_URL" \
--header "Authorization: Bearer $DBGPT_TONGYI_API_KEY" \
--header "Content-Type: application/json" \
--data '{
    "model": "text-embedding-v1",
    "input": {
        "texts": [
        "你好"
        ]
    },
    "parameters": {
        "text_type": "query"
    }
}')

if [[ $? != 0 ]]; then
    print_message "error" "访问通义 API 服务失败，可能存在网络问题!\n"
    exit
fi

access_res=$(printf "$resp" | grep "code" | grep "message")
if [ -n "$access_res" ]; then
    print_message "error" "通义API KEY设置有误!\n"
    exit
else
    print_message "success" "通义API KEY配置成功!\n"
fi

mysql -h "$DBGPT_OB_HOST" -P "$DBGPT_OB_PORT" -u "$DBGPT_OB_USER" -p"$DBGPT_OB_PASSWORD" -D$DBGPT_OB_DATABASE < "./oceanbase-chat-data-example.sql"
mysql -h "$DBGPT_OB_HOST" -P "$DBGPT_OB_PORT" -u "$DBGPT_OB_USER" -p"$DBGPT_OB_PASSWORD" -D$DBGPT_OB_DATABASE -e "SHOW TABLES"
if [[ $? != 0 ]]; then
    print_message "error" "$DB_DATABASE 数据库连接与数据初始化失败!\n"
    exit
else
    print_message "success" "$DB_DATABASE 数据库连接与数据初始化成功~\n"
fi

if [ "$(docker ps -a -q -f name=tugraph_demo)" ]; then
    docker rm -f tugraph_demo
fi

docker run -d -p 7070:7070  -p 7687:7687 -p 9090:9090 \
--name tugraph_demo quay.io/oceanbase-devhub/tugraph-runtime-centos7:4.5.0 \
lgraph_server -d run --enable_plugin true

sleep 5
TUGRAPH_HOST=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' tugraph_demo)
if [ $? != 0 ]; then
    print_message "error" "TuGraph docker 启动失败\n"
    exit
else
    print_message "success" "TuGraph docker 启动成功！\n"
fi

if [ "$(docker ps -a -q -f name=dbgpt)" ]; then
    docker rm -f dbgpt
fi
docker run --ipc host -d -p 5670:5670 \
-e LLM_MODEL=tongyi_proxyllm -e PROXYLLM_BACKEND=qwen-turbo \
-e EMBEDDING_MODEL=proxy_tongyi -e proxy_tongyi_proxy_api_key=$DBGPT_TONGYI_API_KEY \
-e proxy_tongyi_proxy_backend=text-embedding-v3 -e LOCAL_DB_TYPE=sqlite \
-e LOCAL_DB_PATH=data/default_sqlite.db -e VECTOR_STORE_TYPE=OceanBase \
-e OB_HOST=$DBGPT_OB_HOST -e OB_PORT=$DBGPT_OB_PORT \
-e OB_USER=$DBGPT_OB_USER -e OB_PASSWORD=$DBGPT_OB_PASSWORD \
-e OB_DATABASE=$DBGPT_OB_DATABASE -e PROXY_SERVER_URL=$LLM_PROXY_SERVER_URL \
-e TONGYI_PROXY_API_KEY=$DBGPT_TONGYI_API_KEY \
-e GRAPH_STORE_TYPE=TuGraph -e TUGRAPH_HOST=$TUGRAPH_HOST -e TUGRAPH_PORT=7687 \
-e TUGRAPH_USERNAME=admin -e TUGRAPH_PASSWORD=73@TuGraph \
-e GRAPH_COMMUNITY_SUMMARY_ENABLED=True \
-e TRIPLET_GRAPH_ENABLED=True \
-e DOCUMENT_GRAPH_ENABLED=True \
-e KNOWLEDGE_GRAPH_CHUNK_SEARCH_TOP_SIZE=5 \
-e KNOWLEDGE_GRAPH_EXTRACTION_BATCH_SIZE=20 --name dbgpt quay.io/oceanbase-devhub/dbgpt:latest

# Wait for DB-GPT server boot.
TIMEOUT=30
INTERVAL=1
ELAPSED=0
BOOT_OK=0

while [ $ELAPSED -lt $TIMEOUT ]; do
  LAST_LOG=$(docker logs dbgpt --tail 1 2>&1)
  
  if [[ "$LAST_LOG" == *"Code server is ready"* ]]; then
    BOOT_OK=1
    break
  fi
  
  # 等待一段时间后再检查
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [[ $BOOT_OK != 1 ]]; then
    print_message "error" "等待 DB-GPT 启动超过 ${TIMEOUT} 秒\n"
fi

json_data=$(cat <<EOF
{
    "db_type": "oceanbase",
    "db_name": "$DBGPT_OB_DATABASE",
    "file_path": "",
    "db_host": "$DBGPT_OB_HOST",
    "db_port": $DBGPT_OB_PORT,
    "db_user": "$DBGPT_OB_USER",
    "db_pwd": "$DBGPT_OB_PASSWORD",
    "comment": ""
}
EOF
)

add_db_resp=$(curl -s -X POST "http://127.0.0.1:5670/api/v1/chat/db/add" \
-H "Content-Type: application/json" \
-d "$json_data")

access_res=$(printf "$resp" | grep -F '{"success":true')
if [ -n "$access_res" ]; then
    print_message "error" "预先在DB-GPT中创建 OceanBase 连接失败，请稍后根据教程在 Web UI 中设置\n"
    exit
else
    print_message "success" "预先在DB-GPT中创建 OceanBase 连接成功\n"
fi

SERVER_IP=$(curl -s http://ifconfig.me)
print_message "success" "访问 http://${SERVER_IP}:5670 开始使用\n"
