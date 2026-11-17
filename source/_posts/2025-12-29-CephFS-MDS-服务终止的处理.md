---
title: CephFS MDS 服务终止的处理
date: 2025-12-29 09:50:25
tags:
- ceph
- cephfs
- mds
categories:
- 运维
- Ceph
---

## 事件原因

```Bash
root@:~# ceph -s
  cluster:
    id:     5a1b2c3d-0000-4000-8000-000000000000
    health: HEALTH_WARN
            1 filesystem is degraded
            1 MDSs report oversized cache
```

## 解决思路

1. 检查MDS服务
2. 检查是否是之前OOM的问题导致的服务器停止
3. 检查operator日志
## 处理流程概述

- 9:15上班时, 告知minio无法正常访问, 检查ceph发现MDS 状态为降级状态, 服务无法使用
- 检查pod, 发现 public-fs 的两个pod 处于循环崩溃的状态
- 重启pod,  发现仍然会崩溃, 并且出现 OOM
- 第一时间增加MDS的limits限制, 但是没有去滚动更新
- 检查operator中的日志, 发现有个`exit status 16`日志, 表示滚动更新被阻塞
  - 发现日志`have open dirfrag * but not leaf in fragtree_t`
- MDS状态有个为rejoin
- 想办法恢复MDS服务器, 并且删除掉内存限制
- 10:00执行`scrub` 修复,  服务恢复正常, deployment滚动更新

## 处理过程

```Markdown
# 不是OOM的问题

root@:~# ceph fs status
public-fs - 39 clients
=========
RANK      STATE           MDS         ACTIVITY     DNS    INOS   DIRS   CAPS
 0        rejoin      public-fs-b                 8379k  8365k  75.8k  1148
 1        active      public-fs-c  Reqs:    0 /s  41.8k  41.8k  89.0k   800
1-s   standby-replay  public-fs-d  Evts:    0 /s     0      3      1      0
       POOL           TYPE     USED  AVAIL
public-fs-metadata  metadata   523G  24.4T
 public-fs-data0      data     372T  24.4T
 cephfs-data-ec01     data    22.3T  48.8T
# 执行主动 fail 命令, 使其切换MDS实例
ceph mds fail public-fs:0

# 但是 切换MDS后, 另外一个 MDS仍然是rejoin, 说明是元数据损坏
root@:~# ceph fs status public-fs
public-fs - 32 clients
=========
RANK      STATE           MDS         ACTIVITY     DNS    INOS   DIRS   CAPS
 0        failed
 1        active      public-fs-c  Reqs:    0 /s  41.8k  41.8k  89.0k   800
1-s   standby-replay  public-fs-d  Evts:    0 /s     0      3      1      0
       POOL           TYPE     USED  AVAIL
public-fs-metadata  metadata   523G  24.4T
 public-fs-data0      data     372T  24.4T
 cephfs-data-ec01     data    22.3T  48.8T
MDS version: ceph version 18.2.4 (e7ad5345525c7aa95470c26863873b581076945d) reef (stable)

# 决定修复损坏的 MDS
root@:~# ceph tell mds.public-fs-a scrub start / recursive force
2025-12-29T10:03:50.245+0800 789d8a0006c0  0 client.31510743 ms_handle_reset on v2:10.0.0.202:6824/2423071499
2025-12-29T10:03:52.349+0800 789d8a0006c0  0 client.32446078 ms_handle_reset on v2:10.0.0.202:6824/2423071499
{
    "return_code": 0,
    "scrub_tag": "3c3a194e-ecb1-4ac5-95ac-63244872eb41",
    "mode": "asynchronous"
}
root@:~#

# 修复完成后, 两个rank都处于rejoin状态
root@:~# ceph fs status public-fs
public-fs - 39 clients
=========
RANK  STATE       MDS      ACTIVITY   DNS    INOS   DIRS   CAPS
 0    rejoin  public-fs-a            4747k  4733k  75.8k  1148
 1    rejoin  public-fs-d               0      3      1      0
       POOL           TYPE     USED  AVAIL
public-fs-metadata  metadata   523G  24.4T
 public-fs-data0      data     372T  24.4T
 cephfs-data-ec01     data    22.3T  48.8T
STANDBY MDS
public-fs-c
MDS version: ceph version 18.2.4 (e7ad5345525c7aa95470c26863873b581076945d) reef (stable)

# 等待1分钟后, 两个rank 均恢复正常
root@:~# ceph fs status public-fs
public-fs - 39 clients
=========
=========
RANK      STATE           MDS         ACTIVITY     DNS    INOS   DIRS   CAPS
 0        active      public-fs-b  Reqs:  832 /s  1828k  1767k  32.6k  45.7k
 1        active      public-fs-a  Reqs:    1 /s    19     23     25      2
1-s   standby-replay  public-fs-d  Evts:    0 /s     0      3      1      0
0-s   standby-replay  public-fs-c  Evts:  819 /s  63.0k  38.9k  27.9k     0
       POOL           TYPE     USED  AVAIL
public-fs-metadata  metadata   523G  24.4T
 public-fs-data0      data     372T  24.4T
 cephfs-data-ec01     data    22.3T  48.8T
MDS version: ceph version 18.2.4 (e7ad5345525c7aa95470c26863873b581076945d) reef (stable)
```

## 复盘

| **阶段** | **观测到的现象** | **根本原因** | **关键恢复操作** | **结果** |
| --- | --- | --- | --- | --- |
| **初始问题** | 1. Rook Operator 滚动更新被阻塞 (`exit status 16`)。 2. Pod`rook-ceph-mds-public-fs-b` 持续 Back-off/重启。 | Rook 在文件系统冗余不足时，为保证数据安全而阻止更新。 | **诊断：** 确定问题在 Ceph 而非 Kubernetes。 | 确认阻止原因。 |
| **Rank 0 故障** | `public-fs-a`(Rank 0) 卡在`rejoin`状态。`mds`容器日志显示`dirfrag` 元数据错误。 | **Rank 0 元数据区域存在结构性损坏或不一致**。任何 MDS 实例接管此 Rank 都会崩溃。 | **操作：**`ceph mds fail public-fs:0` (针对卡住的 MDS A)。 | 成功触发 Rank 0 故障转移。 |
| **连锁崩溃** | `public-fs-b`接管 Rank 0 后，也立即卡在`rejoin` 状态。 | **元数据问题被转移**：证明是元数据数据本身损坏，而非 MDS 实例问题。 | **诊断：** 确定需要元数据修复 (Scrub)。 | 准备进行修复。 |
| **Scrub 触发** | 对卡在`rejoin`的实例执行`ceph tell mds.public-fs-a scrub start / recursive force`。 | 强制 MDS 对其负责的整个元数据路径进行深度检查和修复。 | **操作：** 运行 Scrub。 | 成功启动异步 Scrub。 |
| **意外恶化** | Rank 1 (原`public-fs-c`) 故障，并转移到`public-fs-d`，两者都进入`rejoin`，集群服务面临中断风险。 | **Scrub 压力或发现错误**：Scrub 操作对集群施加了资源压力，或发现了跨 Rank 的元数据引用错误，导致 Rank 1 连锁崩溃。 | **操作：** 等待 Scrub 流程继续运行。 | 最终两个 Rank 都恢复。 |
| **最终恢复** | 所有 MDS 实例恢复`active`或`standby-replay` 状态。 | **Scrub 成功完成修复**：元数据 Scrub 过程在后台运行，成功找到了并修复了导致 MDS 进程崩溃的结构性错误。 | **等待**：等待 Scrub 流程完成并让 MDS 恢复。 | 文件系统恢复健康。 |

## Q&A

### Q: 什么是Rank, Rank处于非active的状态会怎么样

CephFS会将元数据进行切分, 每个切分被称为subtree, Rank就是管理一个或多个subtree

而Rank就是负载均衡和元数据高并发的实现方式

当某个Rank失效的时候, 这个Rank上对应的元数据将无法访问, 服务就会降级

### Q: Scrub是什么? 为什么能恢复元数据

scrub可以修复大多数常见的元数据损坏或不一致性，例如：

1. 不一致的链接计数
2. 目录蒜片话错误, 标记为`dirfrag`.
3. 元数据对象丢失

scrub(擦洗) 会对所有元数据进行**内存中的元数据缓存**与**存储在元数据池 (Metadata Pool) OSDs 中的实际元数据对象**的验证

**两个层次的 Scrub**：

- **Stat Scrub**：检查元数据对象的一致性（例如，目录文件中的 inode 引用是否匹配）。
- **Deep Scrub (Recursive)**：更深入地检查目录结构，验证目录碎片（DirFrag）树的完整性，并确保所有元数据与底层数据对象的引用一致。

### Q: 为什么会元数据损坏

1. BUG
2. OSD存储时问题, 网络波动问题
3. MDS资源耗尽导致服务被杀死, 重启后元数据不一致
## 后续

避免和应对措施:

1. 取消对MDS的资源限制, 避免服务被杀死
