---
title: CentOS 7 安装 zabbix
date: 2023-07-14 11:18:28
tags:
- zabbix
categories:
- 数通
---

分别使用`二进制`和`docker`来安装 `zabbix 5.0` 和 `zabbix 6.0`

## 二进制安装 zabbix 5.0

### 环境检查

```bash
[root@localhost ~]# cat /etc/centos-release
CentOS Linux release 7.9.2009 (Core)

[root@localhost ~]# uname -r
3.10.0-1160.el7.x86_64

# 关闭SELinux 

vi /etc/selinux/config
SELINUX=disabled
reboot

# 防火墙都要设置放开http 和 10051端口
firewall-cmd --add-service=http --permanent
firewall-cmd --add-port=10051/tcp --permanent
firewall-cmd --reload
```
### 安装zabbix 5.0

bash脚本一键部署

```bash
# 0. 如果是使用自建yum源，设置解析
# echo '10.0.0.1 mirrors.aliyuncs.com mirrors.aliyun.com repo.zabbix.com' >> /etc/hosts

# 1. 获取zabbix 5.0 官方源
rpm -Uvh https://mirrors.aliyun.com/zabbix/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm

# 2. 将zabbix源修改为阿里云源
sed -i 's#http://repo.zabbix.com#https://mirrors.aliyun.com/zabbix#' /etc/yum.repos.d/zabbix.repo

# 3. 安装 zabbix server 和 agent
yum install zabbix-server-mysql zabbix-agent -y

# 4. 为避免应用软件版本冲突，安装 centos-release-scl
# 配置文件存放在 /etc/opt/rh
# 安装位置存放在 /opt/rh 
yum install centos-release-scl -y

# 5. 修改zabbix前端源为 enable
# 修改第11行的 enabled=0 为 enabled=1
sed -i '11s/^enabled=.*/enabled=1/' /etc/yum.repos.d/zabbix.repo

# 6. 安装zabbix前端环境
yum install zabbix-web-mysql-scl zabbix-apache-conf-scl -y

# 7. 安装数据库 mariadb
yum install mariadb-server -y

# 8. 启动数据库，并设置为开启自启
systemctl enable --now mariadb

# 9. 修改数据库密码(db_password)和权限
mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('db_password');DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');FLUSH PRIVILEGES;"

# 10. 创建数据库
mysql -u root -pdb_password -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -u root -pdb_password -e "create user zabbix@localhost identified by 'db_password'; grant all privileges on zabbix.* to zabbix@localhost; flush privileges;"

# 11. 导入数据
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uroot -pdb_password zabbix

# 12. 修改zabbix配置文件，设置数据库密码
sed -i.ori '124a DBPassword=db_password' /etc/zabbix/zabbix_server.conf

# 13. 修改时区
sed -i.ori '25s|.*|php_value[date.timezone] = Asia/Shanghai|' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf

# 14. 解决乱码问题
yum install -y wqy-microhei-fonts
\cp /usr/share/fonts/wqy-microhei/wqy-microhei.ttc /usr/share/fonts/dejavu/DejaVuSans.ttf

# 15. 安装snmp监控程序
yum install net-snmp net-snmp-utils -y
sed -i.ori "56a view    systemview    included   .1" /etc/snmp/snmpd.conf 
systemctl enable --now snmpd.service

# 16. 启动相关服务
systemctl restart zabbix-server zabbix-agent httpd rh-php72-php-fpm
systemctl enable zabbix-server zabbix-agent httpd rh-php72-php-fpm

# 17. 访问zabbix前端
echo "http://$(hostname -I | awk '{print $1}')/zabbix
username: Admin
Password: zabbix"
```


## web安装

登录zabbix前端，进行安装

1. 在 `Welcome to Zabbix` 中，点击 `Next step`

2. 在 `Configure DB connection` 中，填写数据库密码(db_password)

3. 后面的都直接下一步即可


## Docker 安装 zabbix 6.0

### 安装环境配置

```bash
zabbix_pwd="zabbix_pwd" && \
root_pwd="root_pwd" && \
zabbix_server_name="Zabbix Server" && \
server_dir="/opt/zabbix" && \
zabbix_http_port="8081" && \
mkdir -p ${server_dir}/server/{alertscripts,externalscripts,modules} && \
mkdir -p ${server_dir}/agent2/modules
```

### 创建网络

```bash
docker network create --subnet 172.20.0.0/16 --ip-range 172.20.100.0/20 zabbix-net
```

### 创建 mysql8 数据库

```bash
docker run -v /etc/localtime:/etc/localtime \
      --name mysql-server -t \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD=${zabbix_pwd} \
      -e MYSQL_ROOT_PASSWORD=${root_pwd} \
      --network=zabbix-net \
      --restart unless-stopped \
      -d mysql:8.0 \
      --character-set-server=utf8 --collation-server=utf8_bin \
      --default-authentication-plugin=mysql_native_password
```

### 创建zabbix-java-gateway

```bash
docker run -v /etc/localtime:/etc/localtime \
      --name zabbix-java-gateway -t \
      --network=zabbix-net \
      --restart unless-stopped \
      -d zabbix/zabbix-java-gateway:ubuntu-6.0-latest
```

### 创建 zabbix-web-server

```bash
docker run -v /etc/localtime:/etc/localtime \
      --name zabbix-web-service -t \
      -e ZBX_ALLOWEDIP="zabbix-server-mysql" \
      -v /opt/zabbix/web-service:/etc/zabbix \
      --cap-add=SYS_ADMIN --network=zabbix-net \
      -d zabbix/zabbix-web-service:ubuntu-6.0-latest
```

### 启动 zabbx-server

启动 `Zabbix server` 实例，并将其关联到已创建的 `mysql-server` 实例

```bash
docker volume create zabbix-server-volume

docker run -v /etc/localtime:/etc/localtime \
      --name zabbix-server-mysql -t \
      --link zabbix-web-service:zabbix-web-service \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD=${zabbix_pwd} \
      -e MYSQL_ROOT_PASSWORD=${root_pwd} \
      -e ZBX_JAVAGATEWAY="zabbix-java-gateway" \
      -e ZBX_STARTREPORTWRITERS="2" \
      -e ZBX_WEBSERVICEURL="http://zabbix-web-service:10053/report" \
      -v zabbix-server-volume:/etc/zabbix \
      -v ${server_dir}/server/alertscripts:/usr/lib/zabbix/alertscripts \
      -v ${server_dir}/server/externalscripts:/usr/lib/zabbix/externalscripts \
      -v ${server_dir}/server/modules:/usr/lib/zabbix/modules \
      --network=zabbix-net \
      -p 10051:10051 \
      --restart unless-stopped \
      -d zabbix/zabbix-server-mysql:ubuntu-6.0-latest
```

### 启动 zabbix-web 界面

启动 `Zabbix Web` 界面，并将其关联到已创建的 `mysql-server` 实例 和 `zabbix-server-mysql` 实例

```bash
docker run -v /etc/localtime:/etc/localtime \
      --name zabbix-web-nginx-mysql -t \
      -e ZBX_SERVER_HOST="zabbix-server-mysql" \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e PHP_TZ="Asia/Shanghai" \
      -e MYSQL_PASSWORD=${zabbix_pwd} \
      -e MYSQL_ROOT_PASSWORD=${root_pwd} \
      -e ZBX_SERVER_NAME="${zabbix_server_name}" \
      --network=zabbix-net \
      -p ${zabbix_http_port}:8080 \
      --restart unless-stopped \
      -d zabbix/zabbix-web-nginx-mysql:ubuntu-6.0-latest
```

- 默认用户名密码： `Admin/zabbix`

### 启动 Zabbix agent2 服务

1. `Zabbix server` 主机安装 `Zabbix agent2` 服务

```bash
docker volume create zabbix-agent2-volume

docker run -v /etc/localtime:/etc/localtime \
      --name zabbix-agent2 \
      -v zabbix-agent2-volume:/etc/zabbix \
      -e ZBX_HOSTNAME="zabbix-server" \
      -e ZBX_SERVER_HOST="zabbix-server-mysql" \
      -e ZBX_SERVER_PORT=10051 \
      -p 10050:10050 \
      -v ${server_dir}/agent2/modules:/var/lib/zabbix/modules \
      --privileged \
      --network=zabbix-net \
      --restart unless-stopped \
      -d zabbix/zabbix-agent2:ubuntu-6.0-latest

# 查询 zabbix agent2 ip
docker inspect zabbix-agent2 | grep -w "IPAddress"
```

### 解决 Zabbix 乱码问题

```bash
yum install -y wqy-microhei-fonts
docker cp /usr/share/fonts/wqy-microhei/wqy-microhei.ttc zabbix-web-nginx-mysql:/usr/share/fonts/dejavu/DejaVuSans.ttf
```
