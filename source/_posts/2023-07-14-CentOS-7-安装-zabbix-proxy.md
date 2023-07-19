---
title: CentOS 7 安装 zabbix proxy
date: 2023-07-14 16:12:47
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
```

## 安装 zabbix proxy

```bash
# 0. 如果是使用自建yum源，设置解析
# echo '10.0.0.1 mirrors.aliyuncs.com mirrors.aliyun.com repo.zabbix.com' >> /etc/hosts

# 1. 获取zabbix 5.0 官方源
rpm -Uvh https://mirrors.aliyun.com/zabbix/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm

# 2. 将zabbix源修改为阿里云源
sed -i 's#http://repo.zabbix.com#https://mirrors.aliyun.com/zabbix#' /etc/yum.repos.d/zabbix.repo

# 3. 安装 zabbix proxy
yum install -y zabbix-proxy-mysql 

# 4. 安装数据库
yum install mariadb-server -y


# 5. 启动数据库，并设置为开启自启
systemctl enable --now mariadb

# 6. 修改数据库密码(db_password)和权限
mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('db_password');DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');FLUSH PRIVILEGES;"

# 7. 创建数据库
mysql -u root -pdb_password -e "create database zabbix_proxy character set utf8 collate utf8_bin;"
mysql -u root -pdb_password -e "grant all on zabbix_proxy.* to zabbix@'localhost' identified by 'db_password';"

# 8. 导入数据库
zcat /usr/share/doc/zabbix-proxy-mysql*/schema.sql.gz | mysql -u root -pdb_password zabbix_proxy

# 9. 修改zabbix_proxy配置文件，需要确定代理名称和服务器IP
HostName="Zabbix proxy"
ServerIP="192.168.56.20"
sed -i.ori "s/^Hostname=.*/Hostname=$HostName/g; s/Server=127.0.0.1/Server=$ServerIP/g; 196a DBPassword=db_password" /etc/zabbix/zabbix_proxy.conf

# 10. 安装snmp监控程序
yum install net-snmp net-snmp-utils -y
sed -i.ori "56a view    systemview    included   .1" /etc/snmp/snmpd.conf 
systemctl enable --now snmpd.service

# 11. 启动zabbix_proxy
systemctl enable --now zabbix-proxy.service
```