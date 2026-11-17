---
title: Cilium Pod 网段与 Ceph MON 地址冲突
date: 2026-07-29 09:04:01
tags:
- k8s
- cilium
- 故障
categories:
- 运维
- K8S
---

## 一、问题现象

### 1.1 报警入口

PV `pvc-ef750b91-9da7-4547-84c8-7e1f33417638` 持续报错，6 小时内触发 62 次 `VolumeFailedDelete` 事件：

```Bash
Warning  VolumeFailedDelete  rpc error: code = Aborted desc = an operation with the given Volume ID already exists
Warning  VolumeFailedDelete  rpc error: code = DeadlineExceeded desc = context deadline exceeded
```

### 1.2 影响范围

| 资源 | 状态 | 说明 |
| --- | --- | --- |
| PV `pvc-ef750b91...` | Released（卡住） | 300Gi Prometheus 数据卷，Reclaim=Delete，无法删除 |
| PVC `prometheus-...-prometheus-0` | Pending | CSI 无法 provision 新卷 |
| Pod `prometheus-...-prometheus-0` | Pending | 依赖 PVC |
| Pod `test-rbd-storage-...` | ContainerCreating | RBD 挂载失败 |
| Pod `test-cephfs-deployment-...` | ContainerCreating | CephFS 挂载失败 |

---

## 二、根因分析

### 2.1 直接原因：Ceph Monitor 不可达

RBD CSI Plugin 日志中反复出现：

```Bash
failed to connect to volume : failed to get connection: connecting failed: rados: ret=-110, Connection timed out
failed to establish the connection: failed to get connection: connecting failed: rados: ret=-110, Connection timed out
```

`ret=-110` = `ETIMEDOUT`，CSI Plugin 无法与 Ceph Monitor（`10.0.0.201`/`10.0.0.202`/`10.0.0.203:6789`）建立 RADOS 连接。

### 2.2 根因：Cilium `cluster-pool-ipv4-cidr` 与 Ceph Monitor IP 地址冲突

**Cilium 配置**：

```Bash
cluster-pool-ipv4-cidr = 10.0.0.0/8
cluster-pool-ipv4-mask-size = 24
routing-mode = tunnel (VXLAN)
```

**节点 Pod CIDR 分配**：

```Bash
k8s-pve-master-02  → 10.0.0.0/24  ← Ceph Monitor 10.0.0.201/202/203 恰好落在此网段！
k8s-pve-node-02   → 10.0.1.0/24
k8s-pve-master-01 → 10.0.2.0/24
k8s-pve-node-03   → 10.0.3.0/24
k8s-pve-master-03 → 10.0.4.0/24
k8s-pve-node-01   → 10.0.5.0/24
k8s-pve-node-05   → 10.0.6.0/24
k8s-pve-node-04   → 10.0.7.0/24
```

**流量被劫持的原理**：

```Bash
Ceph Mon: 10.0.0.201/202/203  ──(应走物理网络)──→  Ceph 集群
                     │
                     ↓ Cilium BPF 判定 10.0.0.0/8 属于集群 Pod 网络
                     ↓ 将流量封装进 VXLAN 隧道 → k8s-pve-master-02
                     ↓ 但 master-02 上并无 10.0.0.201 这个 Pod
                     ↓
                  连接超时 (ETIMEDOUT)
                     ↓
          RBD/CEPHFS CSI: rados: ret=-110
                     ↓
          PV 删不了 + PVC 造不出 + Pod 起不来
```

1. **从 Pod 出发**（如 `ceph-csi-rbd-provisioner`，无 hostNetwork，IP 为 `10.0.1.201`）：Cilium BPF 判断目标 `10.0.0.201` 属于集群 Pod CIDR，将流量封装进 VXLAN 隧道发往 `k8s-pve-master-02`，但目标地址上无 Pod 监听 → 超时
2. **从 Node 宿主机出发**（CSI nodeplugin 有 hostNetwork，但 Node 上也运行 Cilium Agent）：Cilium 在宿主机网络栈注入 BPF 程序和路由规则，`10.0.0.0/8` 流量被劫持进隧道 → Node 上 ping 10.0.0.201 也不通
---

## 三、修复过程

### 3.1 修改 Cilium cluster-pool CIDR

将 `cluster-pool-ipv4-cidr` 从 `10.0.0.0/8` 改为 `10.128.0.0/9`，避开 Ceph Monitor 所在的 `10.0.0.0/24` 网段。

|  | 修改前 | 修改后 |
| --- | --- | --- |
| cluster-pool | 10.0.0.0/8 | 10.128.0.0/9 |
| 地址范围 | 10.0.0.0 ~ 10.255.255.255 | 10.128.0.0 ~ 10.255.255.255 |
| /24 子网容量 | 256 个 | 128 个（8 节点绰绰有余） |
| 与 Ceph 10.0.0.201-203 冲突 | ✅ 冲突 | ❌ 不冲突 |

### 3.2 操作步骤

```Bash
# Step 1: 修改 Cilium ConfigMap
# cluster-pool-ipv4-cidr: 10.128.0.0/9

# Step 2: 重启 Cilium Operator（读取新 CIDR 配置）
kubectl -n kube-system rollout restart deployment cilium-operator

# Step 3: 清除所有 CiliumNode 的旧 podCIDR
for node in $(kubectl get nodes -o name | sed 's/node\///'); do
  kubectl patch ciliumnode $node --type=merge -p '{"spec":{"ipam":{"podCIDRs":[]}}}'
done

# Step 4: 重启 Cilium DaemonSet（Agent 加载新路由，触发 Operator 重新分配 podCIDR）
kubectl -n kube-system rollout restart daemonset cilium

# Step 5: 确认新 podCIDR 分配成功
kubectl get ciliumnode -o custom-columns='NODE:.metadata.name,POD-CIDR:.spec.ipam.podCIDRs'
```

### 3.3 修复结果

**Cilium Node podCIDR 重新分配（10.128.x.0/24）**：

| 节点 | 旧 Pod CIDR | 新 Pod CIDR |
| --- | --- | --- |
| k8s-pve-master-01 | 10.0.2.0/24 | 10.128.0.0/24 |
| k8s-pve-master-02 | 10.0.0.0/24 | 10.128.1.0/24 |
| k8s-pve-master-03 | 10.0.4.0/24 | 10.128.2.0/24 |
| k8s-pve-node-01 | 10.0.5.0/24 | 10.128.3.0/24 |
| k8s-pve-node-02 | 10.0.1.0/24 | 10.128.4.0/24 |
| k8s-pve-node-03 | 10.0.3.0/24 | 10.128.5.0/24 |
| k8s-pve-node-04 | 10.0.7.0/24 | 10.128.6.0/24 |
| k8s-pve-node-05 | 10.0.6.0/24 | 10.128.7.0/24 |

**PV/PVC 状态恢复**：

| 资源 | 修复前 | 修复后 |
| --- | --- | --- |
| PV `pvc-ef750b91...` | Released（卡住删除） | 已删除 |
| PVC `prometheus-...-prometheus-0` | Pending | Bound（新 PV `pvc-d7e333c7...`） |
| PV `pvc-0ff55a90...` (rbd-pvc-test) | Bound | Bound |
| PV `pvc-2bf1aaf7...` (test-cephfs) | Bound | Bound |
| PV `pv-cephfs-shared-data-0` | Bound | Bound |

**Pod 状态恢复**：

| Pod | 修复前 | 修复后 |
| --- | --- | --- |
| test-rbd-storage | ContainerCreating | Running |
| test-cephfs-deployment | ContainerCreating | Running |
| prometheus-...-prometheus-0 | Pending | Running |

---

## 四、待处理事项

1. **旧 IP Pod 重建**：部分 Pod 仍持有旧 CIDR 的 IP（如 `dev/k8s-agent-gateway-5449b89cd-g7d7v` IP=10.0.1.163 CrashLoopBackOff），需手动 rollout restart 重建以获取新 IP
2. **CiliumNetworkPolicy 例外网段**：`dev/internet-only` 和 `test/internet-only` 策略中 `toCIDRSet` 的 `except` 列表包含 `10.0.0.0/8`，建议同步更新为 `10.128.0.0/9`，避免潜在的策略匹配问题
---

## 五、经验总结

| # | 教训 |
| --- | --- |
| 1 | Cilium `cluster-pool-ipv4-cidr` 应避免与集群外部基础设施网段（Ceph/存储网、管理网）重叠，`10.0.0.0/8` 太宽，容易"吞掉"其他服务 |
| 2 | Ceph Monitor 的 IP 地址在 Cilium cluster-pool 内，会导致 BPF 将 Ceph 流量劫持进 VXLAN 隧道，表现为所有 RBD/CephFS 操作超时 |
| 3 | 修改 `cluster-pool-ipv4-cidr` 后需三步联动：重启 Operator → 清除 CiliumNode 旧 podCIDR → 重启 Agent DaemonSet，仅改 ConfigMap 不会自动生效 |
| 4 | CSI 的 `Aborted` 和 `DeadlineExceeded` 错误是 Ceph 不可达的连锁反应，需从网络层排查根因，不要在应用层打转 |
