---
title: K8S PVC Pending 故障处理
date: 2026-04-02 12:05:35
tags:
- k8s
- pvc
- 故障
categories:
- 运维
- K8S
---

## 事件原因

```YAML
Events:
  Type     Reason                Age                  From                                                                                            Message
  ----     ------                ----                 ----                                                                                            -------
  Warning  ProvisioningFailed    3m7s                 rbd.csi.ceph.com_ceph-csi-rbd-provisioner-8c86d89f5-hqs5r_35d8e816-f86c-405e-af51-3051d2aee8f5  failed to
provision
 volume
with StorageClass "rook-ceph-rbd-xfs": rpc error: code = DeadlineExceeded desc = context deadline exceeded
  Normal   Provisioning          59s (x9 over 4m7s)   rbd.csi.ceph.com_ceph-csi-rbd-provisioner-8c86d89f5-hqs5r_35d8e816-f86c-405e-af51-3051d2aee8f5  External provisioner is pro
visioning volume for claim "doris/meta-doriscluster-sample-fe-1"
  Warning  ProvisioningFailed    59s (x8 over 3m6s)   rbd.csi.ceph.com_ceph-csi-rbd-provisioner-8c86d89f5-hqs5r_35d8e816-f86c-405e-af51-3051d2aee8f5  failed to
provision
 volume
with StorageClass "rook-ceph-rbd-xfs": rpc error: code = Aborted desc = an operation with the given Volume ID pvc-918cb610-fec6-451a-b2e5-96c7d3e7dcc3 already exists
  Normal   ExternalProvisioning  10s (x18 over 4m7s)  persistentvolume-controller                                                                     Waiting for a volume to be
created either by the external provisioner 'rbd.csi.ceph.com' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is runni
ng and correctly registered.
```

## 处理过程

### 故障时间

2026-04-02 约 11:30 - 12:04

### 影响范围

- doris namespace：2 个 FE Pod 无法调度
- PVC：`meta-doriscluster-sample-fe-1`、`meta-doriscluster-sample-fe-2` Pending
### 根因

CSI provisioner 内部缓存残留：第一次创建 PVC 超时（DeadlineExceeded），但 provisioner 内部记录了 Volume ID，后续重试时检测到 "already exists" 报错，即使 Ceph 中实际没有该镜像。

### 解决步骤

1. 确认 Ceph 中无残留 RBD 镜像（已清理）
2. 重启 CSI provisioner 清除内部缓存
   ```Bash
   kubectl rollout restart deployment ceph-csi-rbd-provisioner -n ceph-csi
   ```
3. PVC 自动重新创建并 Bound
### 预防措施

1. **增加 StorageClass 超时时间** — HDD 存储建议配置更长超时
2. **监控 PVC 创建失败** — 及时发现此类卡住状态
3. **定期清理 orphan volume** — CSI 元数据与实际不一致时可用
### 持续时间

约 30 分钟
