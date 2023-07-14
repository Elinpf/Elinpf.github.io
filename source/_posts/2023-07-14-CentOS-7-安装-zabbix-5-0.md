---
title: CentOS 7 安装 zabbix 5.0
date: 2023-07-14 11:18:28
tags:
categories:
---

## 环境检查

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
## 安装zabbix 5.0

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
