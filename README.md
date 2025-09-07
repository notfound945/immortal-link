# Immortal Link

## 项目描述 

Immortal Link 是一个轻量级的服务器/客户端，使用 Lua 5.1.5 编写，运行在 OpenWRT 设备之上，支持多客户端的远程消息传递和WOL广播。

## 功能特性
- 基于 TCP 的长连接通信
- PING/PONG 心跳，实时在线检测
- 客户端指数退避重连（2^n 秒，支持 `--retry-exp` 配置）
- 服务器多客户端管理与广播
- WOL 唤醒（客户端发送 UDP 广播，端口 9）

## 快速开始
```bash
# 启动服务端
lua server/server.lua

# 启动客户端（连接本机，默认最大重试阶数 10）
lua client/client.lua --host local

# 自定义最大重试阶数（例如 12，最后一次等待 2^12 秒后退出）
lua client/client.lua --host 127.0.0.1 --retry-exp 12
```

## 文档
- 客户端

    运行在内网的 OpenWRT 设备之上，与远程服务器建立TCP连接

    文档：client/README.md


- 服务端

    运行在公网服务器之上，监听65530端口，等待客户端连接

    文档：server/README.md

## Make 命令行用法

### 前提

- 已安装 Docker 与 Docker Compose（用于 `server-up`/`server-down`）
- 已安装 Lua（用于 `client-up` 与本地运行）

### 快速查看可用命令

```bash
make help
```

### 服务管理（Docker Compose，位于 server/）

```bash
make server-up
make server-down
```

### 镜像构建/推送/拉取

```bash
make build-arm64
make build-amd64
make push REGISTRY=registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link
make pull
```

### 直接运行容器与进入容器

```bash
make run               # 前台运行，Ctrl+C 停止
make run PORT=65531    # 自定义宿主机端口
make exec              # 进入容器 shell
```

### 容器内 CLI（管理命令）

```bash
make cli CMD='clients'
make cli-send CLIENT=client-1 MESSAGE=hello
make cli-broadcast MESSAGE=hello
make cli-wol CLIENT=client-1 MAC=6c:1f:f7:75:c7:0e
make cli-quit
```

### 本地运行（非容器）

```bash
make run-local ARGS='--daemon --admin-port 65531'
make client-up
```
