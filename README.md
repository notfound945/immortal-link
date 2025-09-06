# Immortal Link

## 介绍

Immortal Link 是一个用于远程执行命令的工具，支持多客户端连接，支持命令执行结果的保存。

## 编译构建

```bash
 docker build -f Dockerfile.server -t immortal-link:latest . 
```

## 上传镜像

```bash
 docker tag immortal-link:latest registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
 docker push registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
```

## 运行

```bash
 docker run -it --rm -p 65530:65530 --name immortal-link immortal-link:latest
```