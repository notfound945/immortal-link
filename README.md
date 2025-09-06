# Immortal Link

## 介绍

Immortal Link 是一个用于远程执行命令的工具，支持多客户端连接，支持命令执行结果的保存。

需要注意：
在**amd64**架构的设备上运行，需要使用**amd64**架构的镜像；同理，在**arm64**架构的设备上运行，也需要使用**arm64**架构的镜像。


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