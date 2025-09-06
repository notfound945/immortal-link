# Immortal Link Docker 部署指南

## 🐳 Docker 服务端部署

### 环境要求
- Docker
- Docker Compose (可选)

### 快速开始

#### 方法1: 使用构建脚本
```bash
# 构建镜像
./docker-build-server.sh

# 运行服务端（交互模式）
docker run -it --rm -p 65530:65530 --name immortal-link-server immortal-link-server:latest

# 后台运行服务端
docker run -d -p 65530:65530 --name immortal-link-server immortal-link-server:latest
```

#### 方法2: 使用 Docker Compose
```bash
# 启动服务端
docker-compose -f docker-compose.server.yml up -d

# 查看日志
docker-compose -f docker-compose.server.yml logs -f

# 停止服务端
docker-compose -f docker-compose.server.yml down
```

### 📁 文件映射

Docker Compose 配置会将容器内的 `/app/outputs` 目录映射到主机的 `./outputs` 目录，这样命令执行结果文件会保存在主机上。

### 🔧 服务端配置

- **基础镜像**: Alpine Linux 3.18 (轻量化)
- **监听端口**: 65530
- **Lua 版本**: 5.1.5
- **依赖库**: luasocket
- **输出目录**: `/app/outputs` (映射到主机 `./outputs`)
- **镜像大小**: ~50MB (相比 Ubuntu 镜像减少 ~80%)

### 📝 服务端命令

在容器运行后，可以通过以下方式与服务端交互：

```bash
# 进入容器交互模式
docker exec -it immortal-link-server /bin/bash

# 然后在容器内可以直接与服务端交互
```

### 🖥️ 客户端连接

客户端现在默认连接端口 65530：

```bash
# 本地连接
lua client.lua

# 连接到远程 Docker 服务端
lua client.lua --host <服务器IP>
```

### 🔍 常用 Docker 命令

```bash
# 查看运行中的容器
docker ps

# 查看服务端日志
docker logs immortal-link-server

# 停止服务端
docker stop immortal-link-server

# 删除容器
docker rm immortal-link-server

# 删除镜像
docker rmi immortal-link-server:latest
```

### 🌐 网络配置

- 容器内端口: 65530
- 主机映射端口: 65530
- 协议: TCP

### 📊 目录结构

```
immortal-link/
├── Dockerfile.server          # 服务端 Docker 构建文件
├── docker-compose.server.yml  # Docker Compose 配置
├── docker-build-server.sh     # 构建脚本
├── server.lua                 # 服务端源码
├── client.lua                 # 客户端源码
└── outputs/                   # 命令执行结果输出目录
```

### 🚀 生产环境部署

对于生产环境，建议：

1. 使用 Docker Compose 进行部署
2. 配置适当的重启策略
3. 设置日志轮转
4. 考虑使用反向代理
5. 配置防火墙规则

### 🛠️ 故障排除

如果遇到问题：

1. 检查端口是否被占用: `lsof -i :65530`
2. 查看容器日志: `docker logs immortal-link-server`
3. 确认防火墙设置允许 65530 端口
4. 验证 Docker 网络配置
