# Immortal Link

## Introduction

Immortal Link is a lightweight server/client for remote messaging and WOL broadcasting with multi-client support.

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

# 启动客户端（连接本机，默认最大重试阶数 7）
lua client/client.lua --host local

# 自定义最大重试阶数（例如 10，最后一次等待 2^10 秒后退出）
lua client/client.lua --host 127.0.0.1 --retry-exp 10
```

## 文档
- 客户端文档：client/README.md
- 服务端文档：server/README.md
