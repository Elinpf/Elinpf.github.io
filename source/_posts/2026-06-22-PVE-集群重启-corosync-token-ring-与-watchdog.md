---
title: PVE 集群重启：corosync token ring 与 watchdog
date: 2026-06-22 19:16:13
tags:
- pve
- 虚拟化
categories:
- 运维
---

## 事件回溯

6.22

- 下午5：50，出现VPN无法登录问题，进行紧急排查
- 6：00，检查到PVE 集群，pve-02和pve-03重启了
- 所有vm都无法启动
- 7：00，检查到是RBD的问题，原因是上午修改ceph的pve-prod用户的权限
- 将所有权限放开后，vm正常启动。
- 8：00开始恢复vm，恢复各个k8s集群
- 8：45，pve-01，pve-02和pve-03都又一次全部重启
- 等待第二天去机房现场检查

6.23

- 到达机房，发现夜间所有服务器又进行了3次重启
- 先将新增集群的数据平面拉起来（因为上一次没有接数据平面的线）
- 接入AI，使用Agent来进行系统性排查问题
- 问题定位到pve-01的nic0反复updown，服务器测检查到有CRC积累
- 更换模块，无效。更换光纤解决
## Ceph权限问题

由于这次更新账号权限，缺少了对mon的rbd的权限，所以导致无法使用rbd，进而vm无法获取盘信息

```text
(base) root@pve-01:~# ceph auth get client.pve-prod
[client.pve-prod]
        key = <REDACTED>
        caps mds = "allow rw fsname=pve-prod-fs"
        caps mon = "allow r"  # <---- 这里导致的, 没有加入rbd
        caps osd = "allow * pool=pve-prod-image, allow rw pool=pve-prod-fs-data0, allow rw pool=pve-prod-fs-metadata"
```

临时放开

```Bash
ceph auth caps client.pve-prod \
  mds "allow *" \
  mon "allow *" \
  osd "allow *"
```

## token ring机制导致的watchdog重启

由于bond0是四元组方式，是个集群令牌，通往pve-04和pve-05正好就hash到了nic0网卡上，而pve-02和pve-03正好是在nic5上，所以为什么之前一直没有问题。单纯是运气好

## 后续

交换机侧增加端口抖动保护，防止类似情况出现

```text
system-view

# 全局开启链路震荡保护，并启用自动恢复特性
link-flap protect enable down-auto-recovery

# 配置自动恢复间隔（可选，默认30秒，这里设为300秒）
shutdown-interval link-flap 300

# 接口配置
interface Ten-GigabitEthernet1/0/1
 port link-flap protect enable down-auto-recovery interval 10 threshold 5
 quit

interface Ten-GigabitEthernet2/0/1
 port link-flap protect enable down-auto-recovery interval 10 threshold 5
 quit
```
