---
title: HCL模拟器与VMware互通
date: 2023-07-07 12:40:56
tags:
categories:
- 数通
---

## 设置vmware虚拟网络编辑器和HCL互通

1. vmware设置虚拟网络编辑器，新增一个vmnet,设置为桥接模式，桥接到vbox网卡上(因为HCL使用的是vbox网卡)

![](1.png)

2. 给虚拟机加一个网卡，网卡自定义为刚刚的vmnet

![](2.png)

3. 给虚拟机配置IP

CentOS7的配置方法：

由于刚刚新增了网卡，先查看网卡UUID，获取新网卡的UUID

```
nmcli conn show
```

将原先的`ens33`网卡信息复制一份为新增网卡信息，我这边的是`ens37`

```
cp /etc/sysconfig/network-scripts/ifcfg-ens33 /etc/sysconfig/network-scripts/ifcfg-ens37
```

修改`ifcfg-ens37`文件

```
BOOTPROTO=static
IPADDR=192.168.56.10
NETMASK=255.255.255.0
GATEWAY=192.168.56.1
NAME=ens37
UUID=<复制的UUID>
DEVICE=ens37
ONBOOT=yes
```


4. 配置HCL的交换机的IP, 即可互通

## 遇到的问题

1. vmware虚拟网络编辑器设置为桥接模式后，又回到NAT模式了

重置恢复

2. 新网卡配置后，隔一会IP又没了

关闭NetworkManager

```
systemctl stop NetworkManager
systemctl disable NetworkManager
systemctl restart network
```
