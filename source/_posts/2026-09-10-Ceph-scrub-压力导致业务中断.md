---
title: Ceph scrub 压力导致业务中断
date: 2026-09-10 13:37:43
tags:
- ceph
- scrub
- 故障
categories:
- 运维
- Ceph
---

## 事件原因

10点出现Jumpserver不可用，开始进行故障排查。

但是这个事情可以结合之前一次的现象，也就是ceph集群的问题。有同事反应，ceph集群看起来是正常的。但是中间有硬中断。 这个描述非常模糊。但是使用AI去检查了一下。 给出来的判断是网络有问题

## 解决思路

1. 这次主要是靠AI来进行问题排查，然后中途通过方向调整和补充背景信息来更正方向
2. 这次使用到了开发的 运维工具套件，来进行协助系统性的排查

通过发现的症状收集，JumpServer服务中断，继续检查ceph，发现MDS服务之前出现过异常

## 处理过程

1. 排查为什么MDS出现异常
2. 出现异常的时候，网络侧发生了什么？ IB网络和以太网络都同时出现了问题吗？不太可能
3. 检查Promethus记录，看看有什么其他没有检查到的问题
## 结果

### 排查方法论

本轮从 "IB fabric 事故" 到 "ceph scrub 风暴" 的转向，靠四个廉价但决定性的数据源：① `node_network_carrier_changes_total`（主机侧链路翻转的隐藏记录仪）；② 双腿同时坍塌的对照实验；③ `ceph_health_detail` 逐检查项时间序列（健康翻转=事件指纹）；④ `ceph_osd_commit_latency_ms/op_wip` 逐 OSD 历史（提交路径的心电图）。死路 14 条全部记入 trace（H1-H8 及其分支），供下次直查。

### 时间线

| 北京时间 | 事件 | 证据 |
| --- | --- | --- |
| 00:30 | （前置）gpu-node-02 的 ceph_cap_reclaim_work 开始 CPU 霸占（dmesg）—— 病态客户端带病入场 | gpu-node-02 dmesg |
| 08:00 | scrub 波开闸（OSD pod 时区=UTC，begin_hour=0 → 08:00 CST）；osd_scrub_sleep=0 无节流 | config + pg dump |
| 08:03-08:49 | pool 12（public-fs-data0）PG 连环 scrub：12.33e@08:03、12.39e@08:17、12.339@08:32、**12.396@08:49:41**（up 全是 nvme OSD） | pg dump SCRUB_STAMP |
| 08:30-08:50 | store-01 五块热盘（nvme4-8n1）读风暴 700→530→188 MB/s（deep-scrub 读+校验和，10-12k IOPS） | node_disk_read |
| 08:49 | 业务 K8S API CRD 404（早期信号） | 控制面日志 |
| 08:50 | 读风暴窒息（700→6 MB/s）—— scrubber 跟着 op 队列一起堵 | node_disk_read |
| 08:54:09 | csi-snapshotter lease 超时 exit 255 | CSI 日志 |
| 08:54:27 | gpu-node-02 停止响应 MDS cap 回收（永久） | sessionmap |
| 08:54:30 | MDS public-fs-b journal 停滞开始 | MDS 日志 |
| 08:55 | **CPU 饱和**：nvme 三兄弟 user+system 84-87%（store-01 system 5%→48%），iowait≈0（盘无罪） | node_cpu |
| 08:55-08:56 | OSD commit 延迟 0-1ms→50-150ms；写 op 积压至 104；SLOW_OPS 告警；health→WARN；**全池写入坍塌**（pve-测试池 83→6、rbd-pool 12→3、fs-metadata 10→0）；业务 K8S 全部 krbd busy=100% 吞吐=0；**5 块卷永久停滞开始**（node-03 mysql/nacos + node-01 zabbix-pg + node-02 ES + node-03 kafka） | commit_latency/op_wip/pool_wr |
| 09:00 | 生产集群 node-03 卷静默停滞定格；09:07-09:11 生产集群 csi 连不上自家 API（etcd 超时）—— 两集群控制面同窗口被打 | 卷 stats/控制面日志 |
| 09:10-09:15 | 压力缓解：停滞客户端已停发（写入压力骤减）+ 最重的 deep-scrub 阶段过去 → CPU 回落 → **积压以 1.2-1.4 GB/s 排空** → OSD 恢复正常延迟 | node_disk_written / CPU |
| 09:13-09:18 | **PVE（用户态 RBD）完全自愈**，写入冲高 95-158 MB/s（积压回放） | pool_wr |
| 09:14-09:16 | 三个 kube-apiserver 先后重启（etcd lease 超时） | 控制面 |
| 09:18 | MDS unlink 风暴（+2883 慢请求）—— **MDS journal 停滞未解除**（fs-metadata 写=0 至 10:36） | MDS |
| 09:26-09:32 | scrub 波仍在继续（12.3a9@09:26、12.372@09:30 深扫、12.390@09:32）—— 已无碍 | pg dump |
| ~10:00 | JumpServer core 挂死可见化（探针杀 pod → 重建循环；web 502） | 应用 |
| **10:36:43** | **MDS 积压瞬间排空**（无内部日志触发）；fs-metadata 写同秒恢复 9MB/s | MDS/pool_wr |
| 10:37-10:40 | JumpServer core+web Ready（自动恢复） | 应用 |
| 10:46-10:48 | **多数内核 krbd 客户端恢复**（追赶型写入突发） | 卷 stats |
| 11:23→至今 | 5 块卷仍 busy=1.00 吞吐=0；gpu-node-02 死锁；MDS LATE_RELEASE 在（85 慢请求卡在 gpu-node-02 的 cap 上） | 卷 stats/ceph log |

**关键时长对比：存储层停滞 ~20 分钟（08:55-09:15），但 MDS 停滞 102 分钟（08:54-10:36），JumpServer 可见中断 10:00-10:38，5 块 krbd 卷和 gpu-node-02 至今未恢复。**

### 为什么 scrub 过去后，有的客户端自愈、有的永久卡死

**四类客户端，四种命运（按恢复能力分层）：**

| 客户端类型 | 机制 | 结局 |
| --- | --- | --- |
| **PVE（qemu/librbd，用户态）** | 请求在 OSD 队列里排队，OSD 恢复后全部完成；用户态 messenger 有重试/重连 | 09:13-09:18 **完全自愈**+积压回放 |
| **内核 krbd（大多数卷）** | 同上，但内核客户端恢复较慢（消息队列排空顺序） | 10:46-10:48 恢复 |
| **内核 krbd（5 块卷）** | **内核 ceph 客户端无超时失效机制**：krbd 块层超时处理器只重置计时器不失败请求、libceph osd_request_timeout=0 —— 挂起的请求既不重发也不失败；连接层进入卡死态（6.8.0-106 已知 libceph 退化：ceph_con_workfn 空转，gpu-node-02 上事发前一周已计数 209 万次） | **永久停滞：busy=1.00 吞吐=0，零报错，只有重启节点能清**（node-02 先例验证） |
| **gpu-node-02 内核 cephfs** | 事前已带病（cap_reclaim_work 00:30 起 CPU 霸占）；事件把"病"转成"死"：4 个 D 状态进程卡 folio_wait_bit/ceph_mdsc_wait_request | **不自愈，需主机级处置** |

**JumpServer 的死亡链条（注意：它不是 RBD 受害者，是 CephFS 受害者）：**

1. core 的数据目录在 CephFS public-fs 上（**同集群所有 RBD 依赖组件 postgres/redis/celery 全程存活**，只有 CephFS 依赖的 core 挂死）
2. 08:54:30 MDS journal 停滞 → 全部 cephfs 元数据操作停摆 → core 挂死 → 探针杀 pod → 重建循环（新 pod 挂载也卡在 MDS）
3. **MDS 为什么停了 102 分钟而存储 09:15 就好了**：journal 管线被 gpu-node-02 死锁客户端的 cap 回收依赖锁死（Ceph 已知失败模式：客户端 session 活着 → 不触发自动驱逐；cap 回收永不完成 → journal 无法 trim）。10:36:43 的解除无内部日志触发（推断为卡住的 RADOS journal 写最终完成或内部条件超时）
4. 10:36 MDS 排空 → 1 分钟后 JumpServer 自愈
5. **即：JumpServer 中断时长 = MDS 停滞时长（102 分钟）≠ 存储停滞时长（20 分钟）；MDS 的长停滞 = 存储 20 分钟踩踏 × gpu-node-02 病态客户端放大**
**mysql 的死亡链条（RBD 受害者 + k8s 调度层死锁）：**

1. mysql-0 的 50G 卷（krbd 挂在 node-03）09:00 静默停滞 —— 属于第 3 类永久 wedge
2. mysql 进程本身在停滞后仍活着（数据在内存/page cache，不碰盘就不死）
3. 11:30 rollout restart 触发死亡：旧 pod unstage（umount）卡在停滞设备 → volumeattachment 清不掉 → 新 pod（node-06）attach 时发现卷仍被 node-03 的 krbd **独占锁**持有 → `Multi-Attach error` → ContainerCreating 悬置
4. 根子 = 楔死的内核状态 + RBD exclusive-lock 不释放；**解法在 node-03 节点本身（重启=清内核状态=释放锁），不在 mysql/STS 侧** —— 即 R1 处置方案
**一句话总结**：scrub 风暴 × 早高峰把 nvme 三兄弟 CPU 打穿 20 分钟是"扳机"；用户态客户端（PVE）扳机一松就活了；内核客户端里，带病或不幸的（gpu-node-02、5 块 krbd 卷）在无超时机制下被永久楔死；MDS 被死锁客户端拖了 102 分钟 —— JumpServer 死于 MDS 的长停滞，mysql 死于停滞卷的独占锁在 k8s 调度层的死锁。
