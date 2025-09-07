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
