# Immortal Link Server

Note:
Use an image matching your system architecture. For **amd64** hosts use **amd64** images; for **arm64** hosts use **arm64** images.


## Build

+ ARM64

```bash
docker build -f server/Dockerfile.server -t immortal-link:latest .
```

+ AMD64

```bash 
docker build -f server/Dockerfile.server --platform linux/amd64 -t immortal-link:latest .
```

## Push image

```bash
docker tag immortal-link:latest registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
docker push registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
```

## Pull image

```bash
docker pull registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
docker tag registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest immortal-link:latest
```

## Run

```bash
docker run -it --rm -p 65530:65530 --name immortal-link immortal-link:latest
```

## Enter container

```bash
docker exec -it immortal-link /bin/sh
```

## CLI usage

```bash
docker exec -it immortal-link lua cli.lua send hello
docker exec -it immortal-link lua cli.lua wol 6c:1f:f7:75:c7:0e
docker exec -it immortal-link lua cli.lua broadcast hello
docker exec -it immortal-link lua cli.lua clients
docker exec -it immortal-link lua cli.lua quit
```

## 本地运行（非容器）

```bash
lua server/server.lua [--daemon] [--admin-port <port>]
```

- 默认客户端监听端口：0.0.0.0:65530/TCP
- 默认管理端口：127.0.0.1:65531/TCP（仅本机可访问）
- `--daemon`：守护模式运行（不读取 stdin，仅处理网络与管理端口）
- `--admin-port`：自定义管理端口（仅绑定在 127.0.0.1）

> 说明：在容器中推荐通过 `docker exec` 调用 `cli.lua` 进行管理，如上方 CLI 示例。

## 命令说明

- `send <message>`：向所有在线客户端发送一条消息
- `broadcast <message>`：以广播前缀向所有客户端发送消息
- `wol <MAC>`：向所有客户端下发唤醒命令，客户端负责在其所在局域网发送 WOL 广播包
- `clients`：列出当前在线客户端
- `quit`：优雅关闭服务端并断开所有客户端

## 心跳与在线检测

- 服务端每 10 秒向客户端发送 `PING`
- 客户端收到 `PING` 会回复 `PONG`；任意消息都会刷新在线时间戳
- 若 30 秒未收到任何消息，服务端判定客户端离线并移除

## 端口与协议

- 客户端连接端口：`65530/TCP`
- 管理端口（本地回环）：`127.0.0.1:65531/TCP`
- 文本行协议（以 `\n` 结尾），无 TLS/加密

## 与 WOL 的关系

- WOL 包由客户端在其局域网内以 UDP 广播发送（默认端口 9）
- 服务端仅负责下发 `WOL:<MAC>` 指令，不直接发送 UDP 广播