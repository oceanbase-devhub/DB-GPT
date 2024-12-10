## 实验背景

🤖️ **DB-GPT是一个开源的AI原生数据应用开发框架(AI Native Data App Development framework with AWEL(Agentic Workflow Expression Language) and Agents)。**

目的是构建大模型领域的基础设施，通过开发多模型管理(SMMF)、Text2SQL效果优化、RAG框架以及优化、Multi-Agents框架协作、AWEL(智能体工作流编排)等多种技术能力，让围绕数据库构建大模型应用更简单，更方便。 

OceanBase 从 4.3.3 版本开始支持了向量数据类型的存储和检索，并且经过适配可以作为 DB-GPT 的可选向量数据库，支持 DB-GPT 对结构化数据和向量数据的存取需求，有力地支撑其上 LLM 应用的开发和落地，同时 DB-GPT 也通过 `chat data`、`chat db` 等应用为 OceanBase 提升了易用性。


## 实验环境

- Git
- [Docker](https://docs.docker.com/engine/install/)
- MySQL 客户端

## 平台搭建步骤

### 1. 获取 OceanBase 数据库

进行实验之前，我们需要先获取 OceanBase 数据库，目前可行的方式有两种：使用 OBCloud 实例或者[使用 Docker 本地部署单机版 OceanBase 数据库](#使用-docker-部署单机版-oceanbase-数据库)。我们在此推荐 OBCloud 实例，因为它部署和管理都更加简单，且不需要本地环境支持。

#### 1.1 注册并开通 OBCloud 实例

进入[OB Cloud 云数据库 365 天免费试用](https://www.oceanbase.com/free-trial)页面，点击“立即试用”按钮，注册并登录账号，填写相关信息，开通实例，等待创建完成。

#### 1.2 获取数据库实例连接串

进入实例详情页的“实例工作台”，点击“连接”-“获取连接串”按钮来获取数据库连接串，将其中的连接信息填入后续步骤中创建的 .env 文件内。

![获取数据库连接串](images/get-connection-info.png)

#### 1.3 创建数据库

创建数据库以存放示例数据以及向量数据。需要注意的是，在设置数据库名称的时候，为了便于用户在 DB-GPT 侧进行后续的操作，强烈不建议用户使用以下四种名称：（因为以下四种数据库名被 DB-GPT 保留，用户虽然能成功在 DB-GPT 侧建立连接，但是无法在 Web UI 中进行其他操作）

- auth
- dbgpt
- test
- public

![在 OBCloud 上创建多个数据库](images/create-db.png)

### 2. 克隆项目

> 现场体验的用户，请在登录上云服务器后，跳转到[4. 启动 Docker 容器](#4-启动-docker-容器)

为了简化部署流程，我们基于 DB-GPT 的 0.6.2 版本进行了修改，并且上传到了我们 fork 的代码仓库中。使用以下指令下载项目代码：

```bash
git clone https://github.com/oceanbase-devhub/DB-GPT
```

### 3. 拉取 Docker 镜像

```bash
docker pull quay.io/oceanbase-devhub/dbgpt:latest
```

### 4. 启动 Docker 容器

进入项目代码所在的目录（以克隆 DB-GPT 项目所在的目录为根目录）：

```bash
cd ./DB-GPT/docker/compose_examples
```

执行 `create_container_with_config_check.sh` 脚本：

```bash
./create_container_with_config_check.sh
```




## 附录

### 使用 Docker 部署单机版 OceanBase 数据库

#### 1. 启动 OceanBase 容器

您可以使用以下命令启动一个 OceanBase docker 容器：

```bash
docker run --name=ob433 -e MODE=mini -e OB_MEMORY_LIMIT=8G -e OB_DATAFILE_SIZE=10G -e OB_CLUSTER_NAME=ailab2024_dbgpt -e OB_SERVER_IP=127.0.0.1 -p 2881:2881 -d quay.io/oceanbase/oceanbase-ce:4.3.3.1-101000012024102216
```

如果上述命令执行成功，将会打印容器 ID，如下所示：

```bash
af5b32e79dc2a862b5574d05a18c1b240dc5923f04435a0e0ec41d70d91a20ee
```

#### 2. 检查 OceanBase 数据库初始化是否完成

容器启动后，您可以使用以下命令检查 OceanBase 数据库初始化状态：

```bash
docker logs -f ob433
```

初始化过程大约需要 2 ~ 3 分钟。当您看到以下消息（底部的 `boot success!` 是必须的）时，说明 OceanBase 数据库初始化完成：

```bash
cluster scenario: express_oltp
Start observer ok
observer program health check ok
Connect to observer ok
Initialize oceanbase-ce ok
Wait for observer init ok
+----------------------------------------------+
|                 oceanbase-ce                 |
+------------+---------+------+-------+--------+
| ip         | version | port | zone  | status |
+------------+---------+------+-------+--------+
| 172.17.0.2 | 4.3.3.1 | 2881 | zone1 | ACTIVE |
+------------+---------+------+-------+--------+
obclient -h172.17.0.2 -P2881 -uroot -Doceanbase -A

cluster unique id: c17ea619-5a3e-5656-be07-00022aa5b154-19298807cfb-00030304

obcluster running

...

check tenant connectable
tenant is connectable
boot success!
```

使用 `Ctrl + C` 退出日志查看界面。

#### 3. 测试数据库部署情况（可选）

可以使用 mysql 客户端连接到 OceanBase 集群，检查数据库部署情况。

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -A -e "show databases"
```

如果部署成功，您将看到以下输出：

```bash
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| oceanbase          |
| test               |
+--------------------+
```

#### 4. 修改参数启用向量模块

可通过下面的命令将`test`租户下的`ob_vector_memory_limit_percentage`参数设置为非零值，以开启 OceanBase 的向量功能模块。

```bash
mysql -h127.0.0.1 -P2881 -uroot@test -A -e "alter system set ob_vector_memory_limit_percentage = 30"
```
