#!/bin/bash

# Docker 构建和运行脚本 - 服务端

echo "=== 构建 Immortal Link 服务端 Docker 镜像 (Alpine Linux) ==="

# 构建 Docker 镜像
docker build -f Dockerfile.server -t immortal-link-server:latest .

if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功"
    echo ""
    echo "=== 运行说明 ==="
    echo "启动服务端容器："
    echo "  docker run -it --rm -p 65530:65530 --name immortal-link-server immortal-link-server:latest"
    echo ""
    echo "后台运行服务端："
    echo "  docker run -d -p 65530:65530 --name immortal-link-server immortal-link-server:latest"
    echo ""
    echo "查看容器日志："
    echo "  docker logs immortal-link-server"
    echo ""
    echo "进入容器交互："
    echo "  docker exec -it immortal-link-server /bin/bash"
    echo ""
    echo "停止容器："
    echo "  docker stop immortal-link-server"
    echo ""
    echo "服务端将在端口 65530 上监听连接"
else
    echo "❌ 镜像构建失败"
    exit 1
fi
