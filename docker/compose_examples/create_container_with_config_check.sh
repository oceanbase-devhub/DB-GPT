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
        echo -e "${BLUE}$message${NC}"
        ;;
    "success")
        echo -e "${GREEN}$message${NC}"
        ;;
    "error")
        echo -e "${RED}$message${NC}"
        ;;
    *)
        echo -e "${BLUE}$message${NC}"
        ;;
    esac
}

update_env_var() {
    local var_name=$1
    local comment=$2
    local current_value=${!var_name}

    # 提示用户输入新的值
    read -p "$(echo -e $BLUE"${comment}（回车以保持当前值: ${current_value}）: "$NC)" new_value

    # 如果用户输入了新的值，则更新环境变量
    if [ -n "$new_value" ]; then
        export $var_name="$new_value"
        echo "$var_name=\"$new_value\"" >> "$TMP_FILE"
    else
        export $var_name="$current_value"
        echo "$var_name=\"$current_value\"" >> "$TMP_FILE"
    fi
}

update_env_var "DBGPT_TONGYI_API_KEY" "设置通义API KEY"
update_env_var "DBGPT_OB_HOST" "设置OceanBase数据库主机地址"
update_env_var "DBGPT_OB_PORT" "设置OceanBase数据库端口"
update_env_var "DBGPT_OB_USER" "设置OceanBase数据库用户名"
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
    print_message "error" "可能存在网络问题!\n"
    exit
fi

access_res=$(echo "$resp" | grep "code" | grep "message")
if [ -n "$access_res" ]; then
    print_message "error" "通义API KEY设置有误!\n"
    exit
else
    print_message "success" "通义API KEY配置成功!\n"
fi

mysql -h "$DBGPT_OB_HOST" -P "$DBGPT_OB_PORT" -u "$DBGPT_OB_USER" -p"$DBGPT_OB_PASSWORD" -D$DBGPT_OB_DATABASE -e "SHOW TABLES"
if [[ $? != 0 ]]; then
    print_message "error" "$DB_DATABASE 数据库连接失败!\n"
    exit
else
    print_message "success" "$DB_DATABASE 数据库连接成功~\n"
fi

docker run --ipc host -d -p 5670:5670 \
-e LLM_MODEL=tongyi_proxyllm -e PROXYLLM_BACKEND=qwen-turbo \
-e EMBEDDING_MODEL=proxy_tongyi -e proxy_tongyi_proxy_api_key=$DBGPT_TONGYI_API_KEY \
-e proxy_tongyi_proxy_backend=text-embedding-v3 -e LOCAL_DB_TYPE=sqlite \
-e LOCAL_DB_PATH=data/default_sqlite.db -e VECTOR_STORE_TYPE=OceanBase \
-e OB_HOST=$DBGPT_OB_HOST -e OB_PORT=$DBGPT_OB_PORT \
-e OB_USER=$DBGPT_OB_USER -e OB_PASSWORD=$DBGPT_OB_PASSWORD \
-e OB_DATABASE=$DBGPT_OB_DATABASE -e PROXY_SERVER_URL=$LLM_PROXY_SERVER_URL \
-e TONGYI_PROXY_API_KEY=$DBGPT_TONGYI_API_KEY --name dbgpt quay.io/oceanbase-devhub/dbgpt:latest
