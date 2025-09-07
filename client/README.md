## Immortal Link Client

### 简介
- 纯 Lua 客户端，使用 LuaSocket 与服务端建立 TCP 长连接
- 支持 WOL（Wake-on-LAN）广播，由服务端下发指令触发
- 内置心跳与自动重连机制

### 运行环境
- Lua 5.1.5
- LuaSocket（需要 tcp/bind/receive/send/sleep/gettime）

### 启动
在项目根目录执行：
```bash
lua client/client.lua [--host <local|dev|ls|IP>] [--retry-exp N]
```

### 参数说明
- **--host**
  - **local**: 连接本机 `127.0.0.1:65530`
  - **dev**: 连接内置开发地址（见代码）
  - **ls**:  连接内置远端地址（见代码）
  - 也可直接传入 IP 地址，例如 `--host 192.168.1.10`
- **--retry-exp N**
  - 指数退避重连最大阶数 N（默认 7）
  - 重连等待序列为：2^1, 2^2, ..., 2^N 秒；超过 N 次后退出

### 示例
```bash
# 本机连接，默认最大阶数 7（最后一次等待 128s）
lua client/client.lua --host local

# 指定远端 IP，最大阶数 10（最后一次等待 1024s 后退出）
lua client/client.lua --host 1.2.3.4 --retry-exp 10
```

### 心跳与在线检测
- 客户端每 10 秒主动发送 `PING`；收到 `PING` 会回 `PONG`
- 任意收到的消息都会刷新客户端的 `lastSeen`
- 若 30 秒未收到任何消息，客户端会断开并触发指数退避重连
- 可在 `client/client.lua` 调整 `heartbeatInterval`、`heartbeatTimeout`

### 自动重连（指数退避）
- 失败后按 2^1, 2^2, ..., 2^N 秒等待重试
- 通过 `--retry-exp N` 配置 N；超过 N 次仍失败则退出

### WOL（Wake-on-LAN）
- 当服务端向客户端发送形如 `WOL:AA:BB:CC:DD:EE:FF` 的消息时，客户端会广播魔术包
- 默认广播参数可在 `client/wol.lua` 中查看/调整（当前端口 9）

### 日志
- 连接成功/失败、重连、WOL 结果会打印日志
- 常规 `PING/PONG` 心跳不打印日志（保持静默）

### 注意事项
- 请确保网络与系统权限允许 UDP 广播（用于 WOL）
- 若运行环境 LuaSocket 不提供 `socket.gettime`，可在代码中添加兼容实现
