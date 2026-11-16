---
title: docker-compose 常用命令
date: 2024-04-26 17:08:28
tags:
- docker
categories:
- 系统
- 工具
---

## 安装

```Bash
# 安装
sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 执行
docker-compose -f <file> -d up
```

## 常用命令

1. **启动和停止服务**：
   - `docker-compose up`：前台启动，启动项目中的所有服务。
   - `docker-compose up -d`：后台启动，启动所有服务并在后台运行。
   - `docker-compose stop`：停止所有服务。
   - `docker-compose restart`：重启所有服务。也可以指定重启某个服务，如`docker-compose restart nginx`。
   - `docker-compose start`：启动服务容器。同样也可以指定启动某个服务，如`docker-compose start nginx`。
2. **查看服务信息**：
   - `docker-compose ps`：查看项目中所有服务的信息。
   - `docker-compose logs`：查看服务容器的输出日志。
3. **构建和重构服务**：
   - `docker-compose build`：构建服务的镜像。
   - `docker-compose up --build`：如果服务镜像不存在，则构建镜像并启动服务。
   - `docker-compose up --force-recreate`：重构服务。
4. **删除所有容器**：
   - `docker-compose down`：删除所有服务容器。
5. **其他常用命令**：
   - `docker-compose pull`：拉取服务镜像。
   - `docker-compose rm`：删除停止的容器。
   - `docker-compose run`：运行一个一次性命令。
   - `docker-compose scale`：设置服务运行容器的个数。
   - `docker-compose pause`：暂停服务。
   - `docker-compose kill`：强制停止服务容器。
   - `docker-compose exec`：在服务镜像的容器中执行命令。
   - `docker-compose port`：打印出某个容器端口所映射的公共端口。
   - `docker-compose push`：推送服务镜像。
   - `docker-compose unpause`：恢复暂停的服务。
这些命令必须在docker-compose.yml文件所在的目录下执行，且可以通过`-f`选项指定Compose模板文件，默认为docker-compose.yml。另外，`-p`选项可用于指定项目名称，默认将使用所在目录名称作为项目名。
