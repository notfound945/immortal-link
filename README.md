# Immortal Link

## 介绍

Immortal Link 是一个用于远程执行命令的工具，支持多客户端连接，支持命令执行结果的保存。

需要注意：在非amd64架构的设备上运行，需要使用arm64架构的镜像。

```bash
[phl@iZwz9eltrfb3v2raj3mvf3Z lua-docker]$ sudo docker run -it --rm -p 65530:65530 --name immortal-link immortal-link:latest
WARNING: The requested image's platform (linux/arm64) does not match the detected host platform (linux/amd64/v4) and no specific platform was requested
exec /bin/sh: exec format error

```

## 编译构建

+ ARM64

```bash
docker build -f Dockerfile.server -t immortal-link:latest .
```

+ AMD64

```bash 
docker build -f Dockerfile.server --platform linux/amd64 -t immortal-link:latest .
```

## 上传镜像

```bash
docker tag immortal-link:latest registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
docker push registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
```

## 下载镜像

```bash
docker pull registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
docker tag registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest immortal-link:latest
```

## 运行

```bash
docker run -it --rm -p 65530:65530 --name immortal-link immortal-link:latest
```

## 进入容器

```bash
docker exec -it immortal-link /bin/sh
```