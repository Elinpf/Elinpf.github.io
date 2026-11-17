---
title: NVIDIA Fabric Manager 与 NVSwitch 路由
date: 2025-12-19 16:32:28
tags:
- nvidia
- nvswitch
- fabric-manager
categories:
- 运维
---

## 参考

- [https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html#getting-started-with-nvlink-subnet-manager](https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html#getting-started-with-nvlink-subnet-manager)

## 软件栈

四代之前的软件栈

第四代NVSwitch软件栈

> DGX B200/B300、NVIDIA HGX B200/B300 8-GPU 和 NVIDIA HGX B100 8-GPU 系统采用第四代 NVSwitch。

NVLSM 服务负责配置 NVSwitch 路由表，而 FM 则处理 GPU 端路由、NVLink 配置，并提供分区管理 API

### FabricManager

FM负责配置NVSwitch内存结构，使所有参与的GPU形成一个统一的内存结构，并监控支持该结构的NVLink。总体而言，FM完成以下任务：

- 配置 NVSwitch 端口之间的路由（早于第四代 NVSwitch）。
- 如果适用，设置 GPU 路由和端口映射。
- 与 GPU 驱动程序协同工作以初始化 GPU。
- 监控网络交换矩阵中的 NVLink 和 NVSwitch 错误。
- 对于无法进行基于自主链路初始化 (ALI) 的 NVLink 训练的系统（第一代和第二代基于 NVSwitch 的系统），FM 完成以下任务：
- 使用NVSwitch 驱动程序初始化和训练 NVSwitch 到 NVSwitch 的 NVLink 互连。
- 与 GPU 驱动程序协同工作，以初始化和训练 NVSwitch 到 GPU 的 NVLink 互连。

### NVLSM

NVLink 子网管理器 (NVLSM) 源自 IB 网络，包含用于对 NVSwitch 和 NVLink 进行编程的附加逻辑。总体而言，NVLSM 为基于 NVSwitch 的系统提供以下功能：

- 发现 NVLink 网络拓扑结构。
- 为所有 GPU 和 NVSwitch NVLink 端口分配本地标识符 (LID)。
- 计算并编写交换机转发表。
- 为 NVLink 分区设置分区密钥 (PKEY)。
- 监控 NVLink 架构的变化。

## 拓扑结构

H200 等拓扑结构

```Bash
(base) root@gpu-node-01:~# lspci | grep -i nvidia
0000:05:00.0 Bridge: NVIDIA Corporation Device 22a3 (rev a1)
0000:06:00.0 Bridge: NVIDIA Corporation Device 22a3 (rev a1)
0000:07:00.0 Bridge: NVIDIA Corporation Device 22a3 (rev a1)
0000:08:00.0 Bridge: NVIDIA Corporation Device 22a3 (rev a1)
0000:18:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
0000:2a:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
0000:3a:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
0000:5d:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
0000:9a:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
0000:ab:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
0000:ba:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
0000:db:00.0 3D controller: NVIDIA Corporation Device 2335 (rev a1)
```

走的是pcie

但是B200的NVSwitch就不会被设备为PCIe设备了, 通过CX7 桥接设备进入

```Bash
lspci | grep -i -E 'nvidia|mella'
05:00.0 Infiniband controller: Mellanox Technologies MT2910 Family [ConnectX-7]
05:00.1 Infiniband controller: Mellanox Technologies MT2910 Family [ConnectX-7]
05:00.2 Infiniband controller: Mellanox Technologies MT2910 Family [ConnectX-7]
05:00.3 Infiniband controller: Mellanox Technologies MT2910 Family [ConnectX-7]
1b:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
43:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
52:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
61:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
9d:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
c3:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
d1:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
df:00.0 3D controller: NVIDIA Corporation Device 29bc (rev a1)
```
