---
title: Proxmox VE 安装部署与使用
date: 2025-10-28 14:43:32
tags:
- pve
- proxmox
- ceph
categories:
- 运维
- 虚拟化
---

## 参考

- [Proxmox VE 中文手册 v7.3 — Promxox VE 中文文档 7.1 文档](https://pve-doc-cn.readthedocs.io/zh-cn/latest/index.html)
- [https://zhuanlan.zhihu.com/p/617024637](https://zhuanlan.zhihu.com/p/617024637)
## 部署集群

使用的是`proxmox-ve_9.0-1.iso`, 基础是debian trixie
### 单节点安装

1. proxomx iso 镜像下载
2. 正常iso安装
3. 修改debian , pve , ceph镜像源
```Bash
mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
mkdir /etc/apt/sources.list.d
cd /etc/apt/sources.list.d

cat > debian.sources <<EOF
Types: deb
URIs: https://mirrors.aliyun.com/debian/
Suites: trixie trixie-updates
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://mirrors.aliyun.com/debian-security/
Suites: trixie-security
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

cat > ceph-no-subscription.sources <<EOF
Types: deb
URIs: https://mirrors.ustc.edu.cn/proxmox/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

cat > pve-no-subscription.sources <<EOF
Types: deb
URIs: https://mirrors.ustc.edu.cn/proxmox/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

1. 登录web界面，`https://IP:8006`
### 集群部署

> 根据官方文档，集群对延迟敏感，虽然流量小，但是需要保障延迟稳定

1. 在主节点上通过web界面创建集群，集群创建后，无法修改名称等
2. 在需要加入的节点上，bash中执行命令，加入到集群中即可
   ```Bash
   pvecm add <cluster-ip>

   #使用ssh密钥的方式
   pvecm add <cluster-ip> --use_ssh
   ```
3. 修改apt源
### 聚合口配置

确认好聚合的端口, 如果无法通过lldp，那么就只能一个一个试了

```Bash
auto lo
iface lo inet loopback

iface nic0 inet manual

iface nic1 inet manual

iface nic2 inet manual

iface nic3 inet manual

iface nic4 inet manual

iface nic5 inet manual

iface nic6 inet manual

iface nic7 inet manual

auto bond0
iface bond0 inet static
        bond-slaves nic0 nic5
        bond-miimon 100
        bond-mode 802.3ad
        bond-xmit-hash-policy layer3+4

auto vmbr0
iface vmbr0 inet static
        address 10.10.33.11/25
        gateway 10.10.33.1
        bridge-ports bond0
        bridge-stp off
        bridge-fd 0

source /etc/network/interfaces.d/*
```

- 配置完后` ifreload -a`
完整的配置，去看vlan网络配置
## 部署服务
### rook-ceph 创建

```YAML
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: pve-prod-image
  namespace: rook-ceph
spec:
  failureDomain: host
  replicated:
    size: 3
```

```YAML
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: pve-prod-fs
  namespace: rook-ceph
spec:
  metadataPool:
    failureDomain: host
    replicated:
      size: 3
  dataPools:
    - failureDomain: host
      replicated:
        size: 3
  preserveFilesystemOnDelete: true
  metadataServer:
    activeCount: 2
    activeStandby: true
    # A key/value list of annotations
    annotations:
    #  key: value
    placement:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: ceph-role
              operator: In
              values:
              - storage-node
      tolerations:
      - key: "node-role.kubernetes.io/control-plane"
        operator: "Exists"
        effect: "NoSchedule"
    #  podAffinity:
    #  podAntiAffinity:
    #  topologySpreadConstraints:
    resources:
      limits:
        cpu: "2"
        memory: "16G"
      requests:
        cpu: "1"
        memory: "4G"
```
### ceph user权限

将rbd和cephfs的都放在一个用户里面

```Bash
# 创建权限
ceph auth get-or-create client.pve-prod \
  mds "allow *" \
  mon "allow *" \
  osd "allow *"
  
# 查看keyring
ceph auth get client.pve-prod

# 更新权限的方式
ceph auth caps client.pve-prod \
  mds "allow rw fsname=pve-prod-fs" \
  mon "profile rbd, profile cephfs" \
  osd "allow * pool=pve-prod-image, allow rw pool=pve-prod-fs-data0, allow rw pool=pve-prod-fs-metadata, allow rw pool=.mgr"
```

权限问题！！！` fsname=cephfs`没有这个fs

```Bash
ceph auth get client.pve-test

# 更新权限，如果没有就 get-or-create
ceph auth caps client.pve-test \
  mds "allow rw fsname=pve-test-fs" \
  mon "profile rbd, profile cephfs" \
  osd "allow * pool=pve-test-image, allow rw pool=pve-test-fs-data0, allow rw pool=pve-test-fs-metadata, allow rw pool=.mgr"
  
```

```Bash
ps auxf | grep mount.ceph
dmesg | tail -n 30 | grep ceph

killall -9 mount.ceph
umount -f /mnt/pve/pve-test-fs 2>/dev/null
systemctl restart pvedaemon pvestatd
df -h | grep pve-test-fs
```

```Markdown
# prod 只读
ceph auth caps client.pve-prod-ro \
  mds "allow r fsname=pve-prod-fs" \
  mon "profile rbd-read-only, profile cephfs" \
  osd "profile rbd-read-only pool=pve-prod-image, allow r pool=pve-prod-fs-data0, allow r pool=pve-prod-fs-metadata, allow r pool=.mgr"

  
ceph auth get client.pve-prod-ro

# test 只读
ceph auth caps client.pve-test-ro \
  mds "allow r fsname=pve-test-fs" \
  mon "profile rbd-read-only, profile cephfs" \
  osd "profile rbd-read-only pool=pve-test-image, allow r pool=pve-test-fs-data0, allow r pool=pve-test-fs-metadata, allow r pool=.mgr"
```
### rbd

id不重要,就是本地命名, pool一定要对

keyring就是整个`ceph.client.admin.keyring`的内容
### cephfs

id不重要

用户名使用`client. `后面的内容

keyring只是**密钥的内容**

~~出现连接超时是因为ceph账号权限不足，~~~~**先全放开**~~~~，添加完成后收紧~~，ceph user权限进行检查

其实存储的关键点在于 `/etc/pve/storage.cfg` 文件和`/etc/pve/priv/ceph/`目录下面的keyring

```YAML
cephfs: pve-test-fs
        path /mnt/pve/pve-test-fs
        content backup,import,iso
        fs-name pve-test-fs
        monhost 10.0.0.201,10.0.0.202,10.0.0.203
        prune-backups keep-all=1
        username pve-test
        
        
<REDACTED>
```

> 如果出现问题，在pve中**`journalctl -xe`**** **检查
有时候部署的时候会有找不到ceph.conf 配置文件的问题
尝试了

- 修改 client 权限为` allow *`
- 手动增加 `/etc/pve/priv/ceph/` 下面的令牌环
- 手动增加 `/etc/ceph/` 下面的令牌环
~~然后就能正常挂载了，当全部还原的时候，仍然可以正常挂载。因为不好复现，所以只能推测大概率是权限的问题，不行的时候，全部添加一遍也没毛病~~

就是权限问题
### 导入qcow2 格式的镜像

1. 修改CephFS存储，保证其内容包含导入

1. 在这个存储中，导入镜像

需要注意的是，**镜像的后缀必须和镜像的文件格式是一致的**，proxmox不会智能区分。导致img（实际为qcow2）导入成raw格式

通过qemu-img info <img> 来查看镜像的实际格式，**根据需要手动修改后缀**

1. 创建镜像，关键点，不定义ISO，磁盘总线使用VirtIO

1. 创建后，因为是VirtIO修改下启动引导

如果要命令行创建硬盘并修改启动顺序，如下

```Bash
# 进入到镜像所在位置，可以上传过来
cd /mnt/pve/pub/import

# 确认文件格式
qemu-img info cirros-0.6.3-aarch64-disk.qcow2

# qm importdisk <vmid> <image> <storage>
qm importdisk 101 cirros-0.6.3-aarch64-disk.qcow2 rbd-pool

# 修改类型为virtio
# qm set <vmid> --scsihw virtio-scsi-pci --<scsi0/virtio0> <storage:disk>
qm set 101 --scsihw virtio-scsi-pci --virtio0 rbd-pool:vm-101-disk-0

# 修改启动顺序
qm set 101 --boot c --bootdisk virtio0
```
### 导入ova格式的镜像

[https://web.archive.org/web/20240907195332/https://www.networkshinobi.com/importing-ova-file-to-proxmox-6-1-3/](https://web.archive.org/web/20240907195332/https://www.networkshinobi.com/importing-ova-file-to-proxmox-6-1-3/)
### vlan网络配置

```Bash
apt install openvswitch-switch -y
```

```text
root@prod-3:/etc/network# cat interfaces | more
auto lo
iface lo inet loopback

auto nic0
iface nic0 inet manual

auto nic1
iface nic1 inet manual

auto nic2
iface nic2 inet manual
    ovs_bridge vmbr1
    ovs_type OVSPort

auto nic3
iface nic3 inet manual

auto nic4
iface nic4 inet manual

auto nic5
iface nic5 inet manual

auto nic6
iface nic6 inet manual

auto nic7
iface nic7 inet manual
    ovs_bridge vmbr1
    ovs_type OVSPort

auto bond0
iface bond0 inet static
        bond-slaves nic0 nic6
        bond-miimon 100
        bond-mode 802.3ad
        bond-xmit-hash-policy layer3+4

auto vmbr0
iface vmbr0 inet static
        address 10.10.33.13/25
        gateway 10.10.33.1
        bridge-ports bond0
        bridge-stp off
        bridge-fd 0

auto bond1
iface bond1 inet manual
  ovs_bridge vmbr1
  ovs_type OVSBond
  ovs_bonds nic2 nic7
  ovs_options bond_mode=balance-tcp lacp=active other_config:lacp-time=fast vlan_mode=trunk trunks=128-138

auto vmbr1
iface vmbr1 inet manual
  ovs_type OVSBridge
  ovs_ports bond1

source /etc/network/interfaces.d/*
```

> 配置后`ifreload -a `出现
`warning: bond1: interface not recognized - please check interface configuration`
原因是`ovs_bonds`这个参数必须要两个接口以上才可以，另外必须ifup一下
需要ifup 一下 `ifup vmbr1 bond1 nic2 nic7`
但是重启后可能会失效, 需要验证auto是否真的可以自动启动

> 完成后，要在SND界面里面点击应用，推送所有，完成后等一等，所有进入available状态

> 同步确认交换机上面的vlan，是否放行了`port trunk permit vlan`
## 虚拟机操作
### 虚拟机的系统盘调整

最好使用LVM作为qcow2的系统盘，容易扩容，当创建后，再给个硬盘，拉到一个卷里面

如果没有使用LVM，则需要

1. 修改导入的磁盘大小
2. 扩展分区，两种方式
```Bash
# 1. 进入 parted 交互界面
sudo parted /dev/sda

# 2. 在 parted 中：
#    (parted) print free    # 查看未分配空间
#    (parted) resizepart 2 100%   # 将第2个分区扩展到100%磁盘空间
#    (parted) quit

# 3. 重新加载分区表
sudo partprobe /dev/sda
```

```Bash
# 安装 cloud-utils（如果尚未安装）
sudo apt update && sudo apt install cloud-utils  # Debian/Ubuntu
# 或
sudo yum install cloud-utils-growpart           # CentOS/RHEL

# 扩展分区（扩展 /dev/sda 的第2个分区）
sudo growpart /dev/sda 2
```

1. 扩展文件系统
```Bash
# 检查文件系统
sudo e2fsck -f /dev/sda2

# 调整文件系统大小以填满分区
sudo resize2fs /dev/sda2
```
### HA 高可用

使用要求：

1. 至少3节点集群，仲裁机制
2. 使用共享存储，ceph
vm的高可用必须手动添加，如果有亲和性的要求，还可以在亲和性中添加规则

故障迁移触发需要2分钟。相当于冷重启，迁移完成vm会有个启动的过程。并且节点恢复后vm不会回迁

> 如果宿主机宕机前没有给虚拟机配置HA, 那么是不会自动切换的, 但是可以手动切换, 核心就是移动虚拟机的conf文件, 在复制的一瞬间就会同步过去. 然后启动即可

```Bash
mv /etc/pve/nodes/{SrcNodeName}/qemu-server/{VMID}.conf /etc/pve/nodes/{DstNodeName}/qemu-server
```
### CloudInit模板的创建和使用

默认情况下 PVE里面的CloudInit模块是没有开启的

```Bash
# 安装 cloud-init
sudo apt install cloud-init

# ubuntu netplan 的方式, 清理
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
sudo rm /etc/ssh/ssh_host_*

# 让 Cloud-Init 只在首次启动时更新 hosts 文件
sudo sed -i "/update_etc_hosts/c \  - ['update_etc_hosts', 'once-per-instance']" /etc/cloud/cloud.cfg

# 最后
cloud-init clean -c all
echo "" > /root/.bash_history
echo "" > /home/user/.bash_history
history -c
```

 然后关机, 在pve主机中

```Markdown
# 检查虚拟机id, 然后设置cloudinit
qm list
qm set <id> --ide2 pve-prod-rbd:cloudinit
```

设置完成后, 就可以在PVE 平台里面使用CloudInit了

然后设置为模板机即可

手动生成machine-id的方式

```Bash
sudo systemd-machine-id-setup
```
### 扩展磁盘

克隆机器后, 可以**调整磁盘大小**, 然后启动后执行一个比较通用的扩容命令, 先修复GPT再扩展

```Bash

sudo gdisk /dev/sda <<EOF
w
Y
EOF

sudo growpart /dev/sda 3
sudo pvresize /dev/sda3
sudo lvextend -r -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
```
## 权限配置
### 按资源池分配权限

假设要根据部门来分配不同的权限, 可以按照这个流程做, 假设是开发部门(devlopment)

1. 创建群组
2. 创建用户
3. 创建资源池
4. 在资源池里面配置权限
### 管理员组

```Markdown
# admin group
pveum group add admin -comment "System Administrators"
pveum acl modify / -group admin -role Administrator
```
## QA
### Q: 导入qcow2硬盘是创建的副本吗？

是
### Q:  如何更换节点名称

建议最好别轻易更换, 如果实在要更换

```Bash
mkdir -p /tmp/qemu ## 创建临时目录用于移动 VM 配置文件
cp /etc/pve/nodes/$original_hostname/qemu-server/* /tmp/qemu/

hostnamectl set-hostname "$new_hostname"
sed -i "s/$original_hostname/$new_hostname/g" /etc/hosts

services=("pveproxy.service" "pvebanner.service" "pve-cluster.service" "pvestatd.service" "pvedaemon.service")
for service in "${services[@]}"
do
systemctl restart "$service"
done

rm -rf "/etc/pve/nodes/$original_hostname"
cp /tmp/qemu/* /etc/pve/nodes/$new_hostname/qemu-server/
rm /tmp/qemu/*
```
### Q: cephfs 添加有问题

有可能是用户权限问题导致的, 先放开一个全部权限的测试, 再收紧
### Q：模板虚拟机备份速度慢

备份作为**链接克隆父模板的虚拟机**特别慢是 **Ceph RBD 的读放大（Read Amplification）问题**，这是 Ceph 的固有特性导致的

解决方案是先完全克隆一个虚拟机，然后针对这个虚拟机进行备份
### Q：对于hosts文件会在每次重启的时候覆盖的问题

需要重新配置cloud-init

```Bash
# 修改 cloud-init 配置
sudo sed -i "/update_etc_hosts/c \  - ['update_etc_hosts', 'once-per-instance']" /etc/cloud/cloud.cfg

# 创建标记文件，告诉 cloud-init 此步骤已执行
sudo touch /var/lib/cloud/instance/sem/config_update_etc_hosts
```
### Q: vm被lock锁定了如何解锁

```Bash
qm status <vm-id>
qm config <vm-id>
qm unlock <vm-id>
```
