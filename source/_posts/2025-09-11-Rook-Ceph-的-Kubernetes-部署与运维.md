---
title: Rook-Ceph 的 Kubernetes 部署与运维
date: 2025-09-11 23:11:09
tags:
- ceph
- rook
- k8s
categories:
- 运维
- Ceph
- K8S
---

- [Ceph Docs](https://rook.io/docs/rook/v1.9/quickstart.html)
## 流程

1. k8s集群搭建，sealos K8S 集群部署流程
2. 环境清理，磁盘清理
3. ceph operator 部署，要将 operator 的ns放置在 rook-ceph下
4. CephCluster 部署，几个关键点
   1. hostNetwork
   2. label要对， `ceph-role: storage-node `
   3. monitor，要关闭，否则osd找不到
   4. 节点上开启modprobe rbd
      1. echo "rbd" >> /etc/modules-load.d/rbd.conf
   5. 节点上开启 modprobe ceph
      1. echo "ceph" >> /etc/modules-load.d/ceph.conf
5. rgw部署，pool，user部署，svc对外暴露，（dashboard + rgw） 对外暴露
6. dns 配置

```Bash
modprobe rbd
modprobe ceph
echo "rbd" >> /etc/modules-load.d/rbd.conf
echo "ceph" >> /etc/modules-load.d/ceph.conf
```

待解决问题：

- 为什么默认http 和 https都可以用？ 用的是什么证书？
- 如何对user进行权限管理？

## 外部集群访问使用ceph

- [Kubernetes集成Ceph_ceph auth get-key client.admin-CSDN博客](https://blog.csdn.net/Moolight_shadow/article/details/119276725)
- [External Cluster Options - Rook Ceph Documentation](https://rook.io/docs/rook/latest-release/CRDs/Cluster/external-cluster/advance-external/?utm_source=chatgpt.com)

```Bash
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}') -- bash
```

### rbd

```Bash
bash-5.1$ ceph mon dump
epoch 3
fsid aaaaaaaa-1111-4111-8111-111111111111
last_changed 2025-09-11T07:11:34.154679+0000
created 2025-09-11T07:11:20.722543+0000
min_mon_release 18 (reef)
election_strategy: 1
0: [v2:10.10.32.14:3300/0,v1:10.10.32.14:6789/0] mon.a
1: [v2:10.10.32.15:3300/0,v1:10.10.32.15:6789/0] mon.b
2: [v2:10.10.32.16:3300/0,v1:10.10.32.16:6789/0] mon.c
dumped monmap epoch 3
bash-5.1$ ceph osd pool ls
.mgr
s3-pool.rgw.control
s3-pool.rgw.meta
s3-pool.rgw.log
s3-pool.rgw.buckets.index
s3-pool.rgw.buckets.non-ec
s3-pool.rgw.otp
.rgw.root
s3-pool.rgw.buckets.data
rbd-pool
public-fs-metadata
public-fs-data0
bash-5.1$ ceph auth get-or-create client.k8s-external-rbd mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=rbd-pool'
[client.k8s-external-rbd]
        key = <REDACTED>
bash-5.1$ ceph auth get-key client.k8s-external-rbd
```

> 注意事项

- keyring和config相关通过 values.yaml 进行修改（测试通过了，就不需要修改了）
- userID，不要前缀！！ client.admin 就是 admin
- monitors也不需要端口号
- 需要配置clusterID需要configmap和sc中都存在，monitors只能在configmap中

```YAML
apiVersion: v1
kind: Secret
metadata:
  name: csi-rbd-secret
  namespace: ceph-csi  # 与CSI驱动同命名空间
stringData:
  # Ceph用户（如k8s-external-rbd）, 不需要前面的 client !!
  # ceph auth get-or-create client.k8s-external-rbd mon 'profile rbd' osd 'profile rbd pool=rbd-pool'
  userID: "k8s-external-rbd"
  # Ceph用户密钥，明文即可
  userKey: "<REDACTED>"

---
# Source: ceph-csi-rbd/templates/csiplugin-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: "ceph-csi-config"
  namespace: ceph-csi
  labels:
    app: ceph-csi-rbd
    chart: ceph-csi-rbd-3-canary
    component: nodeplugin
    release: ceph-csi-rbd
    heritage: Helm
data:
  # 修改 clusterID 和 monitors，不需要 port
  config.json: |-
    [
        {
            "clusterID": "aaaaaaaa-1111-4111-8111-111111111111",
            "monitors": [
                "10.10.32.14",
                "10.10.32.15",
                "10.10.32.16",
                "10.10.32.12",
                "10.10.32.13"
            ]
        }
    ]

  cluster-mapping.json: |-
    []
```

```YAML
# ceph-rbd-sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-block
provisioner: rbd.csi.ceph.com  # RBD CSI驱动的provisioner
parameters:
  # clusterID 就是通过 ceph fsid 获取，同时在configmap 中也要添加
  clusterID: "aaaaaaaa-1111-4111-8111-111111111111"
  # Ceph RBD池名称
  pool: "rbd-pool"
  # Ceph用户（与Secret中的userID一致）
  csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
  csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
  csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
  csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi
  csi.storage.k8s.io/fstype: xfs # 推荐使用 xfs格式
  # RBD镜像格式（默认2）
  imageFormat: "2"
  # RBD镜像特性（启用瘦置备）
  imageFeatures: "layering"
reclaimPolicy: Delete  # 或Retain（删除PVC时保留RBD镜像）
allowVolumeExpansion: true  # 支持卷扩容
```

有问题，检查 `ceph-csi/ceph-csi-rbd-provisioner`,查看是什么原因导致的，3个中间只有一个是能看的，其他两个会有个选举的动作

### cephfs

1. 可以和rbd部署在同一个namespace 下
2. secret中，需要有 adminID 和 adminKey
3. configmap可以和rbd的共用
4. provision 需要指定成 cephfs的
5. sc需要配置fsName

```YAML
apiVersion: v1
kind: Secret
metadata:
  name: csi-cephfs-secret
  namespace: ceph-csi  # 与CSI驱动同命名空间
stringData:
  # Ceph用户（如k8s-external-rbd）, 不需要前面的 client !!
  # ceph auth get-or-create client.cephfs-public mon 'allow r' mds 'allow rw path=/' osd 'allow rwx pool=public-fs-data0, allow rwx pool=public-fs_metadata'
  userID: "cephfs-public"
  userKey: "<REDACTED>"

  # 必须还要有个adminID
  adminID: admin
  adminKey: "<REDACTED>"
```

```YAML
# ceph-rbd-sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-cephfs
provisioner: cephfs.csi.ceph.com # Cephfs CSI驱动的provisioner
parameters:
  # clusterID 就是通过 ceph fsid 获取，同时在configmap 中也要添加
  clusterID: "aaaaaaaa-1111-4111-8111-111111111111"
  # Ceph Cephfs
  fsName: public-fs
  # Ceph用户（与Secret中的userID一致）
  csi.storage.k8s.io/provisioner-secret-name: csi-cephfs-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
  csi.storage.k8s.io/controller-expand-secret-name: csi-cephfs-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
  csi.storage.k8s.io/node-stage-secret-name: csi-cephfs-secret
  csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi

reclaimPolicy: Retain 
allowVolumeExpansion: true  # 支持卷扩容
```

### 添加一个cephfs卷作为PVC

```YAML
# 这个提供 shared 卷的静态挂载方式，默认是在ns default中
# 如果要在其他ns中，修改pv的名字
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
  name: pv-cephfs-shared-data-1-ns-default
spec:
  capacity:
    storage: 10Ti
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
      rootPath: /volumes/manual/shared-data-1/8bcfc5a1-83d6-4152-a192-4a25295e9586
    volumeHandle: 8bcfc5a1-83d6-4152-a192-4a25295e9586 # 随意，但是不能重复

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
      storage: 10Ti  # 需与PV容量一致
  volumeName: pv-cephfs-shared-data-1-ns-default  # 显式绑定到创建的PV
  storageClassName: ""  # 显式表明手动静态绑定模式
```

### rgw 部署

k8s中要创建新的rgw，需要注意一下几点：

1. 因为是hostNetwork，所以需要使用新的监听端口
2. 使用CRD而不是手动创建
3. 手动创建一个svc，用来外部访问的，默认是ClusterIP
4. 创建用户也使用CRD来创建
5. 需要为dashboard创建访问认证用户
```YAML
apiVersion: ceph.rook.io/v1
kind: CephObjectStore
metadata:
  name: s3-dev-pool
  namespace: rook-ceph
spec:
  dataPool:
    application: ""
    failureDomain: host
    mirroring: {}
    quotas: {}
    replicated:
      size: 3
    statusCheck:
      mirror: {}
  gateway:
    hostNetwork: true
    instances: 3
    placement:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: rgw
              operator: In
              values:
              - "true"
    port: 8080 # 修改为不冲突的
    resources: {}
  healthCheck: {}
  metadataPool:
    application: ""
    erasureCoded:
      codingChunks: 0
      dataChunks: 0
    failureDomain: host
    mirroring: {}
    quotas: {}
    replicated:
      size: 3
    statusCheck:
      mirror: {}
  preservePoolsOnDelete: true
  sharedPools:
    dataPoolName: ""
    metadataPoolName: ""
    preserveRadosNamespaceDataOnDelete: false
```

```Bash
# 1. 应用配置
kubectl apply -f - <<EOF
apiVersion: ceph.rook.io/v1
kind: CephObjectStoreUser
metadata:
  name: s3-dev-user
  namespace: rook-ceph
spec:
  store: s3-dev-pool
  displayName: "example dev user"
EOF

# 2. 获取生成的密钥
kubectl -n rook-ceph get secret rook-ceph-object-user-s3-dev-pool-s3-dev-user -o yaml
```

完成后需要在dashboard中查看管理，需要重新生成一次dashboard的认证用户

```Bash
ceph dashboard set-rgw-credentials
```

### Troubleshooting

```Markdown
GRPC error: rpc error: code = InvalidArgument desc = missing ID field 'adminID' in secrets
```

### 待解决

- [x] handless service + **MetalLB**（不需要，因为是hostNetwork的方式，直接写mon地址即可，只要有一个能通，那么会返回完整的monmap，然后根据选举原则
- [x] 权限问题，只能有 rbd-pool 权限

2025/09/28 - rook-ceph 修改为多个public-network ，结论为只能使用一个public-network，因为mon只能有一个

## 运维操作

### mon缩容

> mon存活数量一定不能少于(n+1)/2 ，3个就一定不能少于2，优先匹配4个节点，方便操作
所有操作都必须基于集群的真实状态，盲目执行命令会加剧问题；

需要对mon进行缩容，在ceph-cluster 文件中修改 mon.count: 3，需要等待至少15分钟

原因是operator会一个一个去删除mon，但是当删除一个，成为4的时候，会卡住，因为必须确保mon的数量为奇数，所以要等待15分钟。 此时ceph集群的会显示为不健康，等待即可

当Ceph 与 Kubernetes 资源不一致（mon map 脏数据），需要手动在toolbox里面，将mon状态调整为一致。

比如，我做修改了CephCluster，但是

```text
2025-09-26 09:04:46.667475 I | util: retrying after 1m0s, last error: deployment rook-ceph-mon-c cannot be stopped: exit status 16       
```

可能就是operator害怕修改，所以一直等待，此时观察后，可以适当修改，比如

```Markdown
# 确认清除现状
ceph mon stat
ceph quorum_status --format json-pretty

# 手动删除mon映射，移除无效的 MON 成员
ceph mon remove e
```

### 调整public

```Bash
ceph config get mon public_bind_addr
```

尝试使用 multi network 的方案

### 集群删除清理

rook-ceph 清理集群方案

### 删除掉集群后恢复

当删除掉cephcluster集群后，想要恢复，因为/etc/ceph里面是存储了mon信息的，所有重新apply一下cluster-cr.yaml，然后重启了下operator，就恢复了。 并且osd的内容没有掉

### 单独节点无法挂载rbd

```Go
kubernetes.io/csi: attacher.MountDevice
 failed to create newCsiDriverClient: driver name rbd.csi.ceph.com not found in the list of registered CSI drivers
```

到节点上检查jour -u kubelet，确实有这个报错

检查csinode，进行对比

```YAML
root@demo:~/demo/configs/n9e# kubectl get csinode mid-node-117-02 -o yaml
apiVersion: storage.k8s.io/v1
kind: CSINode
metadata:
  annotations:
    storage.alpha.kubernetes.io/migrated-plugins: kubernetes.io/aws-ebs,kubernetes.io/azure-disk,kubernetes.io/azure-file,kubernetes.io/cinder,kubernetes.io/gce-pd,kubernetes.io/vsphere-volume
  creationTimestamp: "2025-10-17T07:51:54Z"
  name: mid-node-117-02
  ownerReferences:
  - apiVersion: v1
    kind: Node
    name: mid-node-117-02
    uid: 6f5e5022-ea05-414f-b285-b9ee12c04a8f
  resourceVersion: "682570"
  uid: faf5c934-4b7f-4565-9ed3-422f2db04002
spec:
  drivers:
  - name: cephfs.csi.ceph.com
    nodeID: mid-node-117-02
    topologyKeys: null
    
    
root@demo:~/demo/configs/n9e# kubectl get csinode mid-node-117-01 -o yaml
apiVersion: storage.k8s.io/v1
kind: CSINode
metadata:
  annotations:
    storage.alpha.kubernetes.io/migrated-plugins: kubernetes.io/aws-ebs,kubernetes.io/azure-disk,kubernetes.io/azure-file,kubernetes.io/cinder,kubernetes.io/gce-pd,kubernetes.io/vsphere-volume
  creationTimestamp: "2025-10-17T07:51:56Z"
  name: mid-node-117-01
  ownerReferences:
  - apiVersion: v1
    kind: Node
    name: mid-node-117-01
    uid: 5cb5e5be-1d0d-4493-b1ba-2ac6743a95d7
  resourceVersion: "682604"
  uid: 60e53e5f-7d2d-46da-9232-b5c840e99617
spec:
  drivers:
  - name: rbd.csi.ceph.com
    nodeID: mid-node-117-01
    topologyKeys: null
  - name: cephfs.csi.ceph.com
    nodeID: mid-node-117-01
    topologyKeys: null
```

发现117-02少了`rbd.csi.ceph.com`

重启117-02的`ceph-csi-rbd-nodeplugin` POD，即可

### PVC 扩容

如果是PVC创建的pv，直接修改PVC即可，会动态调整大小

如果是手动创建的PV，然后连接的PVC，那么修改ceph后端镜像大小

如果是直接挂载到宿主机上的rbd，那么就是在ceph管理界面里面修改

### 新增osd

1. 首先必须清理磁盘，不管是不是新的，都清理下
2. 需要回填的量是 （新osd）/ (目前总共osd），如果一次性增加过大，那么也会造成负载过大
3. 调整回填速率，get还可以写成（osd.<id>)
```Bash
# 单个 OSD 同时进行的数据回填操作的最大数量， 查看和修改，默认是1， 生产环境推荐3~8
ceph config get osd.0 osd_max_backfills # 针对某个osd
ceph config get osd osd_max_backfills   # 整个osd默认值
ceph config set global osd_max_backfills 5
 
# 控制恢复操作的并发度， 查看和修改，如果是0说明不太正常，ssd建议为3~8
ceph config get osd osd_recovery_max_active
ceph config set global osd_recovery_max_active 5
```

1. （可选）添加osd前设置成不可重平衡和回填
2. 添加磁盘到CephCluster
3. （可选）调整新增权重为0，避免重平衡。然后等业务低峰期时，再调整回1

```Markdown
# 检查osd限制
ceph osd dump | grep full_ratio
```

```Bash
ceph osd unset noout
ceph osd unset noin
ceph osd unset nobackfill
ceph osd unset norebalance
```

2025/11/21 - 34块盘OSD扩容
