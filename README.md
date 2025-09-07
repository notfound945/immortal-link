# Immortal Link

## Introduction

Immortal Link is a lightweight server/client for remote messaging and WOL broadcasting with multi-client support.

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