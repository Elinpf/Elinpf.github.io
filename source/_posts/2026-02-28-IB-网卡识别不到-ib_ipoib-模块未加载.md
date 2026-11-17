---
title: IB 网卡识别不到：ib_ipoib 模块未加载
date: 2026-02-28 10:14:24
tags:
- ib
- rdma
- ipoib
categories:
- 运维
- RDMA
---

## 事件原因

gpu-node-01上面识别到Mellanox网卡，但是网络接口没有正确命名

```Bash
root@gpu-node-01:/mnt/ceph_shared/nvidia/scripts# ./check_400g_ib.sh
400G InfiniBand 设备映射表:
================================
IB设备         速率                   状态       网卡名
================================
mlx5_0 port 1    400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_12 port 1   400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_13 port 1   400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_14 port 1   400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_3 port 1    400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_4 port 1    400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_5 port 1    400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_6 port 1    400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
mlx5_7 port 1    400 Gb/sec (4X NDR)      ACTIVE(LinkUp) N/A
```

## 解决思路

1. 对比正常机，是否有明显差异

## 处理过程

### 对比正常机

故障机

```Markdown
root@gpu-node-01:/mnt/ceph_shared/nvidia/scripts# ls -la /sys/class/infiniband/mlx5_0/
total 0
drwxr-xr-x 4 root root    0 Feb 28 10:10 .
drwxr-xr-x 7 root root    0 Feb  4 15:17 ..
-r--r--r-- 1 root root 4096 Feb 28 10:10 board_id
lrwxrwxrwx 1 root root    0 Feb  4 15:17 device -> ../../../0000:18:00.0
-r--r--r-- 1 root root 4096 Feb 28 10:10 fw_pages
-r--r--r-- 1 root root 4096 Feb  4 15:17 fw_ver
-r--r--r-- 1 root root 4096 Feb  4 15:17 hca_type
-r--r--r-- 1 root root 4096 Feb  4 15:17 hw_rev
-rw-r--r-- 1 root root 4096 Feb 28 10:10 node_desc
-r--r--r-- 1 root root 4096 Feb  4 15:17 node_guid
-r--r--r-- 1 root root 4096 Feb  4 15:17 node_type
drwxr-xr-x 3 root root    0 Feb  4 15:17 ports
drwxr-xr-x 2 root root    0 Feb 28 10:10 power
-r--r--r-- 1 root root 4096 Feb 28 10:10 reg_pages
lrwxrwxrwx 1 root root    0 Feb 28 10:10 subsystem -> ../../../../../../../../class/infiniband
-r--r--r-- 1 root root 4096 Feb  4 15:17 sys_image_guid
-rw-r--r-- 1 root root 4096 Feb  4 15:17 uevent
root@gpu-node-01:/mnt/ceph_shared/nvidia/scripts# ls -la /sys/class/net/ | grep ib
root@gpu-node-01:/mnt/ceph_shared/nvidia/scripts# lsmod | grep -E "mlx5|ib_|ipoib"
ib_umad                45056  18
mlx5_ib               487424  0
ib_uverbs             184320  1 mlx5_ib
macsec                 77824  1 mlx5_ib
ib_core               507904  3 ib_umad,ib_uverbs,mlx5_ib
mlx5_core            2494464  1 mlx5_ib
mlxfw                  36864  1 mlx5_core
psample                16384  1 mlx5_core
tls                   155648  9 mlx5_core
pci_hyperv_intf        12288  1 mlx5_core
```

正常机：

```Bash
root@gpu-node-02:/mnt/ceph_shared/nvidia/scripts# ls -la /sys/class/infiniband/mlx5_0/
total 0
drwxr-xr-x  8 root root    0 Feb 28 10:10 .
drwxr-xr-x  5 root root    0 Feb 11 22:08 ..
-r--r--r--  1 root root 4096 Feb 28 10:10 board_id
lrwxrwxrwx  1 root root    0 Feb 11 22:08 device -> ../../../0000:18:00.0
-r--r--r--  1 root root 4096 Feb 28 10:10 fw_pages
-r--r--r--  1 root root 4096 Feb 11 22:08 fw_ver
-r--r--r--  1 root root 4096 Feb 11 22:08 hca_type
-r--r--r--  1 root root 4096 Feb 11 22:08 hw_rev
drwxr-xr-x  3 root root    0 Feb 28 10:10 mad_sa_cc
drwxr-xr-x 24 root root    0 Feb 28 10:10 mr_cache
-rw-r--r--  1 root root 4096 Feb 11 22:08 node_desc
-r--r--r--  1 root root 4096 Feb 11 22:08 node_guid
-r--r--r--  1 root root 4096 Feb 11 22:08 node_type
drwxr-xr-x  3 root root    0 Feb 11 22:08 ports
drwxr-xr-x  2 root root    0 Feb 28 10:10 power
-r--r--r--  1 root root 4096 Feb 28 10:10 reg_pages
lrwxrwxrwx  1 root root    0 Feb 11 22:22 subsystem -> ../../../../../../../../class/infiniband
-r--r--r--  1 root root 4096 Feb 11 22:08 sys_image_guid
drwxr-xr-x  3 root root    0 Feb 28 10:10 tc
drwxr-xr-x  3 root root    0 Feb 28 10:10 ttl
-rw-r--r--  1 root root 4096 Feb 11 22:08 uevent
root@gpu-node-02:/mnt/ceph_shared/nvidia/scripts# ls -la /sys/class/net/ | grep ib
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs100f0 -> ../../devices/pci0000:a6/0000:a6:02.0/0000:a7:00.0/0000:a8:02.0/0000:ab:00.0/net/ibs100f0
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs100f1 -> ../../devices/pci0000:a6/0000:a6:02.0/0000:a7:00.0/0000:a8:02.0/0000:ab:00.1/net/ibs100f1
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs100f2 -> ../../devices/pci0000:a6/0000:a6:02.0/0000:a7:00.0/0000:a8:02.0/0000:ab:00.2/net/ibs100f2
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs100f3 -> ../../devices/pci0000:a6/0000:a6:02.0/0000:a7:00.0/0000:a8:02.0/0000:ab:00.3/net/ibs100f3
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs112 -> ../../devices/pci0000:14/0000:14:02.0/0000:15:00.0/0000:16:01.0/0000:18:00.0/net/ibs112
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs113 -> ../../devices/pci0000:3a/0000:3a:02.0/0000:3b:00.0/0000:3c:01.0/0000:3e:00.0/net/ibs113
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs114 -> ../../devices/pci0000:5c/0000:5c:02.0/0000:5d:00.0/0000:5e:01.0/0000:60:00.0/net/ibs114
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs115 -> ../../devices/pci0000:6d/0000:6d:02.0/0000:6e:00.0/0000:6f:01.0/0000:71:00.0/net/ibs115
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs116 -> ../../devices/pci0000:94/0000:94:02.0/0000:95:00.0/0000:96:01.0/0000:98:00.0/net/ibs116
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs117 -> ../../devices/pci0000:b7/0000:b7:02.0/0000:b8:00.0/0000:b9:01.0/0000:bb:00.0/net/ibs117
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs118 -> ../../devices/pci0000:d9/0000:d9:02.0/0000:da:00.0/0000:db:01.0/0000:dd:00.0/net/ibs118
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs119 -> ../../devices/pci0000:ea/0000:ea:02.0/0000:eb:00.0/0000:ec:01.0/0000:ee:00.0/net/ibs119
lrwxrwxrwx  1 root root 0 Feb 11 22:08 ibs120 -> ../../devices/pci0000:a6/0000:a6:02.0/0000:a7:00.0/0000:a8:00.0/0000:a9:00.0/net/ibs120
root@gpu-node-02:/mnt/ceph_shared/nvidia/scripts# lsmod | grep -E "mlx5|ib_|ipoib"
ib_ipoib              155648  0
ib_cm                 147456  2 rdma_cm,ib_ipoib
mlx5_ib               548864  0
ib_uverbs             200704  2 rdma_ucm,mlx5_ib
macsec                 77824  1 mlx5_ib
ib_umad                45056  18
ib_core               524288  8 rdma_cm,ib_ipoib,iw_cm,ib_umad,rdma_ucm,ib_uverbs,mlx5_ib,ib_cm
mlx5_core            2809856  1 mlx5_ib
mlxfw                  36864  1 mlx5_core
psample                16384  1 mlx5_core
mlxdevm               184320  1 mlx5_core
tls                   155648  1 mlx5_core
mlx_compat             20480  12 rdma_cm,ib_ipoib,mlxdevm,mlxfw,iw_cm,ib_umad,ib_core,rdma_ucm,ib_uverbs,mlx5_ib,ib_cm,mlx5_core
pci_hyperv_intf        12288  1 mlx5_core
```

### 解决方案

可以看到是缺少了`ib_ipoib`这个内核模块

```Bash
modprobe ib_ipoib
```

添加即可

## 结果

可以正常识别

## 后续

但是要注意重启是否还是会导致内核模块丢失
