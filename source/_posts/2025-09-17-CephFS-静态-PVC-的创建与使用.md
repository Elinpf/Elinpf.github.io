---
title: CephFS 静态 PVC 的创建与使用
date: 2025-09-17 16:38:42
tags:
- cephfs
- csi
- pvc
categories:
- 运维
- Ceph
- K8S
---

## 参考

- [https://github.com/ceph/ceph-csi/blob/devel/docs/static-pvc.md#cephfs-static-pvc](https://github.com/ceph/ceph-csi/blob/devel/docs/static-pvc.md#cephfs-static-pvc)
- [ceph 创建 static pvc_loaded mounter: kernel-CSDN博客](https://blog.csdn.net/chenhongloves/article/details/134018873)

## 前提条件

“静态 PVC”指的是：

- 你先在 Ceph 集群里手动创建 subvolume（子卷）或 subvolume group（子卷组），
- 然后在 Kubernetes 中手动创建 PersistentVolume(PV)，指向这个子卷（不通过 StorageClass 动态provision），
- 最后创建 PVC 去绑定这个 PV。
前提条件包括：

1. CephFS 文件系统必须存在，且你有权限创建 subvolume / subvolume group。
2. Ceph-CSI 驱动要已经部署好，并且配置中 subvolume group 名称等与 Ceph 集群一致。
3. 准备好连接 Ceph 的 secret（密钥），k8s 能到 Cephmonitor，并能访问数据/元数据池。
4. PV 的 ReclaimPolicy 要根据你希望保留或释放子卷来设定（常用 Retain）。
## 流程

### 创建卷

```Markdown
# 在 public-fs 中创建 manual 这个卷组
ceph fs subvolumegroup create public-fs manual

# 在 manual 卷组中创建 shared-data 这个卷，10G， --size 是字节
ceph fs subvolume create public-fs shared-data-0 manual --size=10737418240 

# 查看卷路径
ceph fs subvolume getpath public-fs shared-data-0 manual
```

### 创建 secret, pv, pvc

```YAML
# ceph-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret-user-shared
  namespace: ceph-csi
stringData:
  userID: admin
  userKey: "<REDACTED>"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-cephfs-shared-data-0
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  csi:
    driver: cephfs.csi.ceph.com
    fsType: ext4
    nodeStageSecretRef:
      name: ceph-secret-user-shared
      namespace: ceph-csi
    volumeAttributes:
      fsName: public-fs
      subvolumeGroup: manual
      clusterID: aaaaaaaa-1111-4111-8111-111111111111 # ceph fsid
      monitors: 10.0.0.201:6789,10.0.0.202:6789,10.0.0.203:6789 # 对于外部ceph集群，需要mon地址
      staticVolume: "true"
      provisionVolume: "false" # 非自动提供
      rootPath: /volumes/manual/shared-data-0/4f9d7a22-eb22-4383-94dd-8f1249a2ee75
    volumeHandle: 4f9d7a22-eb22-4383-94dd-8f1249a2ee75 # 随意，但是不能重复

---
# cephfs-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-shared-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi  # 需与PV容量一致
  volumeName: pv-cephfs-shared-data-0  # 显式绑定到创建的PV
  storageClassName: ""  # 显式表明手动静态绑定模式
```

### 创建 deployment

```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cephfs-static-pvc-test
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cephfs-static-pvc-test
  template:
    metadata:
      labels:
        app: cephfs-static-pvc-test
        
    spec:
      containers:
        - name: busybox
          image: harbor.example.com/example/ubuntu:24.04
          command: ["sleep", "3600"]
          volumeMounts:
            - name: static-pvc
              mountPath: /root/shared
      volumes:
        - name: static-pvc
          persistentVolumeClaim:
            claimName: cephfs-shared-pvc
```
