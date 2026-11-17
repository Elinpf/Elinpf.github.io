---
title: 使用 cephadm 搭建 Ceph 集群
date: 2025-09-04 18:18:52
tags:
- ceph
- cephadm
categories:
- 运维
- Ceph
---

## 虚拟环境

3台Ubuntu 24.04  4C8G

```Bash
192.168.100.103 vm1
192.168.100.154 vm2
192.168.100.136 vm3
```

o外每台2个20G硬盘，裸盘加上即可另外每台2个20G硬盘，裸盘加上即可

3 台节点能互相解析主机名并 SSH 通信（免密登录）

## 部署

#### 配置hosts

```Bash
cat >> /etc/hosts <<EOF
192.168.100.103 vm1
192.168.100.154 vm2
192.168.100.136 vm3
EOF
```

#### 安装cephadm

```Bash
[root@ceph-node-1 ~]# CEPH_RELEASE=19.2.3
[root@ceph-node-1 ~]# curl --silent --remote-name --location https://download.ceph.com/rpm-${CEPH_RELEASE}/el9/noarch/cephadm

[root@ceph-node-1 ~]# mv cephadm /usr/local/bin/
[root@ceph-node-1 ~]# chmod +x /usr/local/bin/cephadm 

[root@ceph-node-1 ~]# cephadm bootstrap \
  --mon-ip 192.168.15.129 \
  --cluster-network 192.168.15.0/24 \
  --allow-fqdn-hostname
```

- `--mon-ip`：node1 的 IP（用作初始 MON）
- `cluster-network 192.168.15.0/24`
  - 用来指定 Ceph 的**集群内部流量网段**（OSD 之间的数据复制、心跳等）。
  - 如果你不指定，Ceph 默认会把**public network**和**cluster network** 混用。
- `--allow-fqdn-hostname` 允许FQDN格式的主机名，例如：ceph-node-1.localdomain
如果要单机版部署做测试，加上`--single-host-defaults`参数

还可以添加dashboard的参数

如果镜像拉取不下来，可以直接修改 cephadm 这个脚本，因为它就是个python脚本

- 运行完后会：
  - 创建一个最小 Ceph 集群（MON + MGR）
  - 生成`/etc/ceph/ceph.conf`和`/etc/ceph/ceph.client.admin.keyring`
  - 启动 cephadm orchestrator
  - 在` /var/lib/ceph/<ceph_Cluster_ID>`生成ceph相关配置

> 如果后面需要修改`public-network` 和 `cluster-network`

ceph config set mon public_network 192.168.15.0/24
ceph config set mon cluster_network 172.16.0.0/24

IB网络同样，使用IPoIB即可

#### 访问ceph集群

分为docker内部执行和宿主机方式的执行

```Bash
方式一: 使用cephadm shell交互式配置
[root@ceph-node-1 ~]# cephadm shell   # 注意，此命令会启动一个新的容器，运行玩后会退出！
Inferring fsid bbbbbbbb-2222-4222-8222-222222222222
Inferring config /var/lib/ceph/bbbbbbbb-2222-4222-8222-222222222222/mon.ceph-node-1/config
Using ceph image with id '2bc0b0f4375d' and tag 'v18' created on 2024-07-24 06:19:35 +0800 CST
quay.io/ceph/ceph@sha256:6ac7f923aa1d23b43248ce0ddec7e1388855ee3d00813b52c3172b0b23b37906

[root@ceph-node-1 ~]#  ceph -s
  cluster:
    id:     bbbbbbbb-2222-4222-8222-222222222222
    health: HEALTH_WARN
            OSD count 0 < osd_pool_default_size 3
 
  services:
    mon: 1 daemons, quorum ceph-node-1 (age 14m)
    mgr: ceph-node-1.gqogmi(active, since 10m)
    osd: 0 osds: 0 up, 0 in
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:     
 

  方式二: 使用cephadm非交互式配置，依旧会启动容器，运行玩后会退出！
[root@ceph-node-1 ~]# cephadm shell -- ceph -s
Inferring fsid bbbbbbbb-2222-4222-8222-222222222222
Inferring config /var/lib/ceph/bbbbbbbb-2222-4222-8222-222222222222/mon.ceph-node-1/config
Using ceph image with id '2bc0b0f4375d' and tag 'v18' created on 2024-07-24 06:19:35 +0800 CST
quay.io/ceph/ceph@sha256:6ac7f923aa1d23b43248ce0ddec7e1388855ee3d00813b52c3172b0b23b37906
  cluster:
    id:     bbbbbbbb-2222-4222-8222-222222222222
    health: HEALTH_WARN
            OSD count 0 < osd_pool_default_size 3
 
  services:
    mon: 1 daemons, quorum ceph-node-1 (age 12m)
    mgr: ceph-node-1.gqogmi(active, since 8m)
    osd: 0 osds: 0 up, 0 in
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:     
 

  方式三: 安装ceph通用包，其中包含所有ceph命令，包括ceph、rbd、mount.ceph（用于挂载CephFS文件系统）等【推荐使用】
apt -y install ceph-common
# 或者通过 cephadm 安装
# [root@ceph-node-1 ~]# cephadm add-repo --release Squid  # 此步骤是配置本地的apt源
# [root@ceph-node-1 ~]# cephadm install ceph-common  # 此步骤，相当于apt -y install ceph-common
...
Installing repo GPG key from https://download.ceph.com/keys/release.gpg...
Installing repo file at /etc/apt/sources.list.d/ceph.list...  # 会在宿主机创建源文件并安装，速度较慢，请耐性等待!
Updating package list...
Completed adding repo.
Installing packages ['ceph-common']

[root@ceph-node-1 ~]# ceph -v
ceph version 19.2.1 (e7ad5345525c7aa95470c26863873b581076945d) reef (stable)

[root@ceph-node-1 ~]# ceph -s  # 直接在宿主机访问即可
  cluster:
    id:     bbbbbbbb-2222-4222-8222-222222222222
    health: HEALTH_WARN
            OSD count 0 < osd_pool_default_size 3
 
  services:
    mon: 1 daemons, quorum ceph-node-1 (age 22m)
    mgr: ceph-node-1.gqogmi(active, since 18m)
    osd: 0 osds: 0 up, 0 in
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:     
```

#### 基于命令行的方式修改Dashboard账号密码

```Bash
  1.修改admin的密码为1
[root@ceph-node-1 ~]#  echo '<your-password>' | ceph dashboard set-login-credentials admin -i -
******************************************************************
***          WARNING: this command is deprecated.              ***
*** Please use the ac-user-* related commands to manage users. ***
******************************************************************
Username and password updated
[root@ceph-node-1 ~]#  
```

### 添加主机集群

#### 查看ceph集群

```Bash
root@vm1:/etc/ceph# ceph orch host ls
HOST  ADDR             LABELS  STATUS  
vm1   192.168.100.103  _admin          
1 hosts in cluster
```

#### 复制ceph的ssh公钥到其他主机

```Bash
# 编辑配置文件 [所有节点都需要操作] [允许root用户ssh登录]
vim /etc/ssh/sshd_config

# 添加以下参数
PermitRootLogin yes          # 允许root登录
PasswordAuthentication yes   # 允许密码登录（临时）
PubkeyAuthentication yes     # 启用密钥认证

# 重启服务
systemctl restart ssh

# 秘钥放到其他服务器上,只需要在管理节点操作
ssh-copy-id -f -i /etc/ceph/ceph.pub vm2
ssh-copy-id -f -i /etc/ceph/ceph.pub vm3
```

#### 添加集群主机

```Bash
# 在目标主机上安装依赖
apt-get install -y lvm2

# 添加主机
root@vm1:/etc/ceph# ceph orch host add vm2 192.168.100.154
Added host 'vm2' with addr '192.168.100.154'
root@vm1:/etc/ceph# ceph orch host add vm3 192.168.100.136
Added host 'vm3' with addr '192.168.100.136'
root@vm1:/etc/ceph# 

# 添加管理主机
ceph orch host add host4 10.10.0.104 --labels _admin
```

#### 添加MON服务

```Markdown
# 例如：明确指定要在 vm1, vm2, vm3 这三台主机上部署 MON
ceph orch apply mon --placement "vm1,vm2,vm3"

# 或者：告诉 Ceph 我需要 3 个 MON，请自动选择可用的主机来部署
ceph orch apply mon 3
```

### OSD管理

#### 添加OSD

一个设备想要加入ceph集群，要求满足2个条件:
    - 1.设备未被使用;
    - 2.设备的存储大小必须大于5GB;

```Bash
# 检查环境
root@vm1:~# ceph orch device ls
HOST  PATH      TYPE  DEVICE ID                                             SIZE  AVAILABLE  REFRESHED  REJECT REASONS                               
vm1   /dev/sdb  hdd                                                        20.0G  Yes        6m ago                                                  
vm1   /dev/sdc  hdd                                                        20.0G  Yes        6m ago                                                  
vm1   /dev/sr0  hdd   VMware_Virtual_SATA_CDRW_Drive_01000000000000000001  3150M  No         6m ago     Has a FileSystem, Insufficient space (<5GB)  
vm2   /dev/sdb  hdd                                                        20.0G  Yes        10m ago                                                 
vm2   /dev/sdc  hdd                                                        20.0G  Yes        10m ago                                                 
vm2   /dev/sr0  hdd   VMware_Virtual_SATA_CDRW_Drive_01000000000000000001  3150M  No         10m ago    Has a FileSystem, Insufficient space (<5GB)  
vm3   /dev/sdb  hdd                                                        20.0G  Yes        8m ago                                                  
vm3   /dev/sdc  hdd                                                        20.0G  Yes        8m ago                                                  
vm3   /dev/sr0  hdd   VMware_Virtual_SATA_CDRW_Drive_01000000000000000001  3150M  No         8m ago     Has a FileSystem, Insufficient space (<5GB)  
root@vm1:~# 

root@vm1:~# lsblk -f
NAME                      FSTYPE      FSVER            LABEL                           UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
sda                                                                                                                                          
├─sda1                                                                                                                                       
├─sda2                    ext4        1.0                                              4fefae24-7218-4350-a734-b53fd1ef4b3a      1.4G    11% /boot
└─sda3                    LVM2_member LVM2 001                                         YTWNZB-Y0to-EkPX-669D-oYyx-PcdI-blglwx                
  └─ubuntu--vg-ubuntu--lv ext4        1.0                                              b51e1720-3462-4f97-b7ef-a10e9e4db4cd      7.4G    53% /
sdb                                                                                                                                          
sdc                                                                                                                                          
sr0                       iso9660     Joliet Extension Ubuntu-Server 24.04.3 LTS amd64 2025-08-05-23-54-07-00                                
root@vm1:~# 
```

```Bash
root@ceph-node-1:~# ceph orch daemon add osd ceph-node-1:/dev/sdb
Created osd(s) 0 on host 'ceph-node-1'
root@ceph-node-1:~# 
root@ceph-node-1:~# ceph orch daemon add osd ceph-node-1:/dev/sdc
Created osd(s) 1 on host 'ceph-node-1'
root@ceph-node-1:~# 
root@ceph-node-1:~# ceph orch daemon add osd ceph-node-2:/dev/sdb
Created osd(s) 2 on host 'ceph-node-2'
root@ceph-node-1:~# 
root@ceph-node-1:~# ceph orch daemon add osd ceph-node-2:/dev/sdc
Created osd(s) 3 on host 'ceph-node-2'
root@ceph-node-1:~# 
root@ceph-node-1:~# ceph orch daemon add osd ceph-node-2:/dev/sdd
Created osd(s) 4 on host 'ceph-node-2'
root@ceph-node-1:~# 
root@ceph-node-1:~# ceph orch daemon add osd ceph-node-3:/dev/sdb
Created osd(s) 5 on host 'ceph-node-3'
root@ceph-node-1:~# 
root@ceph-node-1:~# ceph orch daemon add osd ceph-node-3:/dev/sdc
Created osd(s) 6 on host 'ceph-node-3'

```

### 一键部署所有可用设备，单独操作更为保险

```Bash
ceph orch apply osd --all-available-devices

```

### 调整OSD的目标内存

```Bash
# 设置更合理的内存目标（如 2GB）
# 这里指的是OSD 守护进程内存最大使用值，超过了宿主机的内存上限可能会ERR
for osd in 0 1 2 3 4 5 6; do
  ceph config set osd.$osd osd_memory_target 2147483648  # 2GB
done

# 重启 OSD 使配置生效
ceph osd set noout
for osd in 0 1 2 3 4 5 6; do
  ceph orch daemon restart osd.$osd
  sleep 30  # 间隔 30 秒避免震荡
done
ceph osd unset noout

```

### 如果发现osd处于down的状态可以检查一下权限设置

```Bash
root@ceph-node-1:~# chown -R  ceph:ceph  /var/lib/ceph/

温馨提示:
  - 1.此步骤会在"/var/lib/ceph/<Ceph_Cluster_ID>/osd.<OSD_ID>/fsid"文件中记录对应ceph的OSD编号对应本地的磁盘设备标识。
  - 2.比如查看ceph142节点的硬盘和OSD的对应关系如下:
[root@ceph-node-2 ~]# ll -d /var/lib/ceph/cccccccc-3333-4333-8333-333333333333/osd.*
drwx------ 2 167 167 4096 Aug 21 15:18 /var/lib/ceph/cccccccc-3333-4333-8333-333333333333/osd.2/
drwx------ 2 167 167 4096 Aug 21 15:19 /var/lib/ceph/cccccccc-3333-4333-8333-333333333333/osd.3/
drwx------ 2 167 167 4096 Aug 21 15:22 /var/lib/ceph/cccccccc-3333-4333-8333-333333333333/osd.6/
[root@ceph-node-2 ~]# 
[root@ceph-node-2 ~]# cat  /var/lib/ceph/cccccccc-3333-4333-8333-333333333333/osd.*/fsid
68ff55fb-358a-4014-ba0e-075adb18c6d9
b9096186-53af-4ca0-b233-01fd913bdaba
d4ccefb2-5812-4ca2-97ca-9642ff4539f2
[root@ceph-node-2 ~]# 
[root@ceph-node-2 ~]# lsblk  # 不难发现，ceph底层是基于lvm技术磁盘的。
NAME                                                                                        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
...
sdb                                                                                           8:16   0   300G  0 disk 
└─ceph--bb7e7dd0--d4e2--4da2--9cfb--da1dcd70222d-osd--block--68ff55fb--358a--4014--ba0e--075adb18c6d9
                                                                                            253:1    0   300G  0 lvm  
sdc                                                                                           8:32   0   500G  0 disk 
└─ceph--5b511438--e561--456f--a33e--82bfc9c4abfd-osd--block--b9096186--53af--4ca0--b233--01fd913bdaba
                                                                                            253:2    0   500G  0 lvm  
sdd                                                                                           8:48   0  1000G  0 disk 
└─ceph--0d9e77e1--051d--4ba6--8274--cfd85e213ab9-osd--block--d4ccefb2--5812--4ca2--97ca--9642ff4539f2
                                                                                            253:3    0  1000G  0 lvm  
...
[root@ceph-node-2 ~]# 
```

当找不到的时候，需要确定是否是因为占用导致的，先umount，然后摧毁重建

> 不要用 ceph-osd 工具！！会有权限问题

```Markdown
# 详细看清理集群的方案
wipefs -a /dev/nvme0n1

# 刷新
ceph orch device ls --refresh
```

#### 删除OSD

```Bash
# 先确定osd对应的是哪个磁盘, 目标主机上
apt install ceph-volume
ceph-volume lvm list

# 标记为out，触发数据迁移
ceph osd out <OSD_ID>

# 等待数据迁移完成， 这一阶段可能要等几分钟到几小时，取决于 PG 数量和数据量。
ceph -s

# 完成后确定PG不再分布在该OSD上
ceph osd df tree
ceph pg ls-by-osd <OSD_ID>

# 下线清理OSD
ceph osd down <OSD_ID>
ceph osd crush remove osd.<OSD_ID>
ceph osd rm <OSD_ID>
ceph auth del osd.<OSD_ID>

# （可选）清空磁盘
sudo wipefs -a --force "$DEVICE_PATH" || true
    
# 清除分区表（这一步会永久删除所有分区和数据！）
sudo sgdisk --zap-all --clear "$DEVICE_PATH" || true
    
# 额外使用 dd 清零磁盘开头部分，确保元数据彻底清除（可选但彻底）
sudo dd if=/dev/zero of="$DEVICE_PATH" bs=1M count=100 status=progress oflag=direct || true
```

可以使用脚本安全删除

```Bash
#!/bin/bash
#
# Ceph OSD 一键下线 & 删除脚本
# 用法: ./osd_remove.sh <OSD_ID> [<DEVICE_PATH>]
# 例子: ./osd_remove.sh 5 /dev/sdb
#
# 注意：
#   - 请在有 ceph CLI 的节点执行
#   - DEVICE_PATH 仅在需要清空磁盘时传入（可选）

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "用法: $0 <OSD_ID> [<DEVICE_PATH>]"
    exit 1
fi

OSD_ID=$1
DEVICE_PATH=${2:-}

echo ">>> 开始下线 OSD.$OSD_ID"

# 标记 OSD out
echo ">>> 标记 OSD.$OSD_ID 为 out..."
ceph osd out $OSD_ID || true

echo ">>> 等待 PG 迁移完成..."
while true; do
    HEALTH=$(ceph health | grep -E "HEALTH_OK")
    PG=$(ceph -s | grep -E "active+clean" | awk '{print $1}')
    if [[ -n "$HEALTH" ]]; then
        echo ">>> 集群健康，迁移完成"
        break
    else
        echo ">>> 等待中... (当前PG状态: $PG)"
        sleep 30
    fi
done

# 标记 OSD down
echo ">>> 标记 OSD.$OSD_ID 为 down..."
ceph osd down $OSD_ID || true

# 删除 crush map 记录
echo ">>> 从 CRUSH map 移除 OSD.$OSD_ID..."
ceph osd crush remove osd.$OSD_ID || true

# 删除 osdmap 记录
echo ">>> 从 OSDMap 移除 OSD.$OSD_ID..."
ceph osd rm $OSD_ID || true

# 删除认证
echo ">>> 删除 OSD.$OSD_ID 的认证..."
ceph auth del osd.$OSD_ID || true

# 清理磁盘
if [ -n "$DEVICE_PATH" ]; then
    echo ">>> 清理磁盘 $DEVICE_PATH ..."
    sudo wipefs -a --force "$DEVICE_PATH" || true
    
    # 清除分区表（这一步会永久删除所有分区和数据！）
    sudo sgdisk --zap-all --clear "$DEVICE_PATH" || true
    
    # 额外使用 dd 清零磁盘开头部分，确保元数据彻底清除（可选但彻底）
    sudo dd if=/dev/zero of="$DEVICE_PATH" bs=1M count=100 status=progress oflag=direct || true
fi

echo ">>> 已完成 OSD.$OSD_ID 删除"

# 检查状态
echo ">>> 当前 OSD 状态:"
ceph osd tree

echo ">>> 当前集群健康状态:"
ceph -s
```

### 安装Ceph客户端 & 用户创建

```Markdown
# 客户机
apt install -y ceph-common

# 创建用户，权限只放通固定pool
ceph auth get-or-create client.k8s mon 'profile rbd' osd 'profile rbd pool=demo-rbd' > client.user.keyring
scp /etc/ceph/ceph.{conf,client.user.keyring} <HOST>:/etc/ceph/
```

## 清理方案

### 清理集群

使用的方式是清除 docker + 相关文件夹 + 磁盘清洗

> 不可逆操作！！！ 警惕执行

```Bash
#!/bin/bash
# 🔥 彻底清理 Cephadm 集群节点脚本 - clean_ceph_node.sh
# 警告：此脚本具有高度破坏性，会永久删除 Ceph 数据和指定磁盘上的所有内容！
# 使用方法：sudo bash clean_ceph_node.sh

set -e # 如果任何命令失败，则退出脚本

# ============ 配置区域：请根据您的实际情况修改 ============
# 请仔细确认要清理的磁盘设备名，错误的设置会导致数据丢失！
DISKS=( "/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1" ) # 将示例替换为您的实际磁盘，例如 ("/dev/sdb" "/dev/sdc")
# ========================================================

echo "⚠️  开始执行 Ceph 节点彻底清理脚本"
echo "⚠️  此操作将销毁所有 Ceph 数据且不可恢复！"
read -p "❓ 确认继续吗？(yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "操作已取消。"
    exit 1
fi

echo "🚦 第 1 阶段：停止并删除所有 Ceph 容器"
# 强制停止所有名称中包含 'ceph' 的容器
sudo docker rm -f $(sudo docker ps -a -q --filter "name=ceph") 2>/dev/null || echo "没有找到可停止的 Ceph 容器，继续..."

#echo "🧹 第 2 阶段：清理 Docker 镜像和资源"
# 删除所有 Ceph 相关镜像
#sudo docker rmi -f $(sudo docker images -q --filter "reference=ceph/*") 2>/dev/null || echo "没有找到 Ceph 镜像，继续..."
# 清理 Docker 占用的所有闲置资源（网络、卷、构建缓存等）
sudo docker system prune -af --volumes

echo "🗑️  第 3 阶段：删除本地文件和目录"
# 递归删除 Ceph 的关键目录
sudo rm -rf /var/lib/ceph/
sudo rm -rf /etc/ceph/
sudo rm -rf /var/log/ceph/
sudo rm -rf /var/lib/cephadm/

echo "💾 第 4 阶段：彻底清理磁盘（危险操作！）"
for DISK in "${DISKS[@]}"; do
    echo "正在清理磁盘: $DISK"
    # 检查磁盘是否存在
    if [[ ! -b "$DISK" ]]; then
        echo "  警告：磁盘 $DISK 不存在，跳过。"
        continue
    fi
    
    # 1. 尝试卸载任何可能挂载的分区
    for MOUNTPOINT in $(lsblk -n -o MOUNTPOINT "$DISK"* 2>/dev/null || true); do
        if [[ -n "$MOUNTPOINT" ]]; then
            sudo umount -f "$MOUNTPOINT" || true
        fi
    done
    
    # 2. 擦除文件系统签名
    sudo wipefs -a --force "$DISK" || true
    
    # 3. 清除分区表（这一步会永久删除所有分区和数据！）
    sudo sgdisk --zap-all --clear "$DISK" || true
    
    # 4. 额外使用 dd 清零磁盘开头部分，确保元数据彻底清除（可选但彻底）
    sudo dd if=/dev/zero of="$DISK" bs=1M count=100 status=progress oflag=direct || true
    
    echo "  已完成对 $DISK 的清理。"
done

echo "清理卷信息"
sudo dmsetup remove_all

echo "🔍 第 5 阶段：清理 LVM 卷（如果存在）"
# 移除可能残留的 Ceph LVM 卷组
sudo vgremove -f $(sudo vgs -o name --noheadning | grep -i ceph) 2>/dev/null || echo "没有找到 Ceph VG，继续..."
# 移除可能残留的 Ceph LVM 物理卷
sudo pvremove -f $(sudo pvs -o name --noheadning | grep -i ceph) 2>/dev/null || echo "没有找到 Ceph PV，继续..."

echo "✅ 节点清理完成！"
echo "建议：现在可以重启该节点以确保所有更改生效，或者继续在其他节点执行此脚本。"
```

## 存储池管理

### 查看存储池

```Bash
root@vm1:~# ceph osd pool ls
.mgr
rbd

root@vm1:~# ceph osd pool ls detail
pool 1 '.mgr' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 1 pgp_num 1 autoscale_mode on last_change 27 flags hashpspool stripe_width 0 pg_num_max 32 pg_num_min 1 application mgr read_balance_score 6.00
pool 2 'rbd' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 34 lfor 0/0/32 flags hashpspool stripe_width 0 application rbd read_balance_score 1.50
```

### 添加存储池

```Bash
ceph osd pool ls
ceph osd pool create demo 128
rados df
```

### 删除存储池

有保护机制

##### nodelete=false和mon_allow_pool_delete=true属性都同时满足时，存储池才会被删除！

```Bash
root@vm1:~# 
root@vm1:~# ceph osd pool delete demo
Error EPERM: WARNING: this will *PERMANENTLY DESTROY* all data stored in pool demo.  If you are *ABSOLUTELY CERTAIN* that is what you want, pass the pool name *twice*, followed by --yes-i-really-really-mean-it.
root@vm1:~# ceph osd pool delete demo demo --yes-i-really-really-mean-it
Error EPERM: pool deletion is disabled; you must first set the mon_allow_pool_delete config option to true before you can destroy a pool
root@vm1:~#      
root@vm1:~# 
root@vm1:~# ceph osd pool get demo nodelete
nodelete: false
root@vm1:~# 
root@vm1:~# 
root@vm1:~# ceph tell mon.* injectargs --mon_allow_pool_delete=true
mon.vm1: {}
mon.vm1: mon_allow_pool_delete = '' 
mon.vm2: {}
mon.vm2: mon_allow_pool_delete = '' 
mon.vm3: {}
mon.vm3: mon_allow_pool_delete = '' 
root@vm1:~# 
root@vm1:~# ceph osd pool delete demo demo --yes-i-really-really-mean-it
pool 'demo' removed
root@vm1:~# 
```

## 用户管理

### 创建用户

```Bash
# 创建只能访问特定 pool 的用户
ceph auth get-or-create client.k8s mon 'profile rbd' osd 'profile rbd pool=demo-rbd' > client.user.keyring
```

### 查询用户

```Bash
root@vm1:/etc# ceph auth get client.k8s
[client.k8s]
        key = <REDACTED>
        caps mon = "profile rbd"
        caps osd = "profile rbd pool=demo-rbd"
```

## 块存储管理

### 创建

```Markdown
# 创建 pool（示例 pool 名称 rbdpool，pg/pg_num 根据规模调整）
ceph osd pool create rbdpool 128
ceph osd pool ls

# 标记为 rbd 应用（使 pool 对 rbd 特性可用）
ceph osd pool application enable rbdpool rbd

# 使用rbd 初始化( 当已经标记为 rbd 应用时就不需要使用了）
rbd pool init rbddpool

# 创建 rbd 镜像（1G）
rbd create rbdpool/testing --size 1G

# 列出镜像
rbd ls rbdpool -l
rbd info test-rbd/testing
```

### Linux客户端映射、格式化、挂载

```Bash
apt install -y ceph-common

# 查看 image -> showmapped
rbd showmapped

# 映射到本地块设备（默认使用 /etc/ceph 中的 keyring）
rbd map rbdpool/testing
# 或者显式指定 id/钥匙文件
rbd map rbdpool/testing --id client.k8s --keyring /etc/ceph/client.k8s.keyring

# 查看新出现的块设备
lsblk

# 假设映射为 /dev/rbd0，格式化并挂载
sudo mkfs.ext4 /dev/rbd0
sudo mkdir -p /mnt/rbdtest
sudo mount /dev/rbd0 /mnt/rbdtest

# 验证
df -h /mnt/rbdtest
```

### 开机自动挂载

```Bash
[root@harbor-node ~]# vim /etc/rc.d/rc.local 

...
rbd -p example-rbd map mysqld
rbd -p example-rbd map wordpress
mount /dev/rbd0 /example/data/mysql
mount /dev/rbd1 /example/data/wordpress
```

### 卸载并取消映射

```Bash
# 先卸载文件系统
sudo umount /mnt/rbdtest

# 取消映射
rbd unmap /dev/rbd0
# 或用 image 名称
rbd unmap rbdpool/testing

# 再确认没有映射
rbd showmapped

# 查看是否有东西挂载在上面
rbd status rbdpool/testing
```

### 删除镜像与池（不可逆操作！）

```Markdown
# 删除镜像（会进入 trash）
rbd rm rbdpool/testing

# 查看 trash（如果需要彻底清除）
rbd trash ls
rbd trash purge --pool rbdpool --image-id <id>

# 删除 pool（非常危险，且 MON 默认禁止删除 pool）
# 先允许 pool 删除（如果需要）
ceph config set mon mon_allow_pool_delete true

# 真正删除 pool（两次写池名以确认）
ceph osd pool delete rbdpool rbdpool --yes-i-really-really-mean-it
```

> 删除 pool 会导致数据不可恢复，且 MON 需要`mon_allow_pool_delete=true`才允许删除。

### RBD 安全建议（用于 K8s / 客户端）

**不要**把`client.admin` key 分发给普通客户端。为客户端/CSI 创建受限 key，例如：

```Bash
# 为 Kubernetes/客户端创建受限 rbd 用户（只允许对 rbdpool 操作）
ceph auth get-or-create client.k8s mon 'profile rbd' osd 'profile rbd pool=rbdpool' -o /etc/ceph/client.k8s.keyring

# 查看 key 内容
cat /etc/ceph/client.k8s.keyring
```

在 K8s 中使用时把 key 的`key` 字段 base64 后放进 Secret。这样客户端只能访问指定 pool。

## RGW 对象存储

### 部署 RGW

如果是k8s 部署，则使用CRD手动部署方式

```Bash
ceph orch apply rgw <rgw-name> --placement="3"
```

### 创建RGW用户并拿到AK/SK （用 radosgw-admin)

如果是k8s 部署，则使用CRD手动部署方式

```Markdown
# 创建用户并返回 keys
radosgw-admin user create --uid="testuser" --display-name="Test User"  > rgw_user.json

# 输出中会包含 'keys' 字段（access_key, secret_key），保存好用于测试 S3 请求
```

### 使用rclone 创建桶、上传、下载

```Bash
# 安装 rclone
apt install rclone

# 配置 rclone
# /root/~.config/rclone/rclone.conf
[test]
type = s3
provider = Other
env_auth = false
access_key_id = <REDACTED>
secret_access_key = <REDACTED>
endpoint = http://vm1:80

# 创建桶
rclone mkdir test:test-bucket

# 复制
rclone copy ./install_docker.sh test:test-bucket/

# 查询
rclone ls test://
```

### 删除桶、用户、服务

```Markdown
# 删除 RGW 用户（谨慎）
radosgw-admin user rm --uid="testuser" --purge-data

# 停掉/移除 RGW service（orchestrator）
ceph orch ls  # 查找 rgw 服务名
ceph orch rm rgw.<name>  # 或者按文档移除
```

### 其他操作

#### 修改rgw端口

```YAML
ceph orch ls --service-type rgw --export > rgw_spec_current.yaml

# 修改，或者添加其中的 spec.rgw_frontend_port: <port>
service_type: rgw
service_id: myrgw
placement:
  hosts:
  - vm1
  - vm2
spec:
  rgw_frontend_port: 3380
  
# 应用
ceph orch apply -i rgw_spec_current.yaml

# 验证
ceph orch ps --daemon-type rgw
ceph orch ps
```

## CephFS

建议直接在Web界面创建，一次到位

### 创建文件系统

```Bash
# 创建池（metadata + data）
ceph osd pool create fs_data 128
ceph osd pool create fs_metadata 32

# （可选）把 data pool 标记为 bulk
ceph osd pool set fs_data bulk true

# 创建文件系统
ceph fs new demo-fs fs_metadata fs_data
```

### 部署MDS

```Markdown
# 部署MDS
## 声明一个MDS服务
ceph orch apply mds demo-fs

## 部署守护进程
ceph orch daemon add mds demo-fs vm1
ceph orch daemon add mds demo-fs vm2
ceph orch daemon add mds demo-fs vm3

# 查看状态
ceph mds stat
ceph fs status demo-fs

root@vm1:/etc# ceph fs status demo-fs
demo-fs - 0 clients
=========
RANK  STATE           MDS              ACTIVITY     DNS    INOS   DIRS   CAPS  
 0    active  demo-fs.vm2.zuvrbj  Reqs:    0 /s    10     13     12      0   
    POOL       TYPE     USED  AVAIL  
fs_metadata  metadata  96.0k  37.8G  
  fs_data      data       0   37.8G  
    STANDBY MDS       
demo-fs.vm1.tbbkyh  
MDS version: ceph version 19.2.3 (c92aebb279828e9c3c1f5d24613efca272649e62) squid (stable)
```

> CephFS 需要至少一个 active MDS 才能提供服务；可以部署多个 MDS（1 active + 多 standby）以保证高可用。

### 客户端挂载

```Bash
# 创建 client.fsuser 可以选择保存到本地，或者一次性使用
ceph auth get-or-create client.fsuser \
  mon 'allow r' \
  mds 'allow rw' \
  osd 'allow rw pool=fs_data, allow rw pool=fs_metadata' \
  - o /etc/ceph/client.fsuser.keyring

# 使用 client.keyring（例如 client.admin 或受限 client.fsuser）
# 不需要 client. 这个前缀
sudo mkdir -p /mnt/cephfs
sudo mount -t ceph 192.168.15.129:6789:/ /mnt/cephfs -o name=admin,secret=<key>
# 或指定 id/keyring 文件，文件只能包含key值!!
sudo mount -t ceph 192.168.15.129:6789:/ /mnt/cephfs -o name=fsuser,secretfile=/etc/ceph/client.fsuser.keyring

# 验证
df -h /mnt/cephfs
ls /mnt/cephfs
```

### 卸载与移除MDS

```Markdown
# 卸载客户端
sudo umount /mnt/cephfs

# 停掉/移除 MDS（orchestrator）
ceph orch daemon rm mds.myfs.vm1  # 或用实际 daemon 名称
# 检查 mds 状态，等待所有 mds 停止
ceph mds stat

# 删除文件系统（注意：会删除元数据及相关指向）
ceph fs rm myfs --yes-i-really-really-mean-it

# 或者先手动删除 pools：
ceph osd pool delete fs_data fs_data --yes-i-really-really-mean-it
ceph osd pool delete fs_metadata fs_metadata --yes-i-really-really-mean-it
```

## 一、集群整体状态检查

### 集群健康状态
```bash
ceph -s                  # 简洁显示集群状态
ceph health detail       # 详细展示健康问题
```

### 监控节点（Mon）信息
```bash
ceph mon dump            # 查看Mon节点列表（含地址，用于对外暴露）
ceph quorum_status       # 查看Mon节点仲裁状态
ceph quorum_status --format json-pretty  # 格式化显示仲裁状态
```

### 主机与服务进程
```bash
ceph orch host ls        # 查看集群主机列表
ceph orch ls             # 查看orch服务列表
ceph orch ps             # 查看所有服务进程状态
ceph orch ps --hostname <主机名>  # 查看指定主机的进程（如：ceph orch ps --hostname vm1）
ceph orch ps --daemon-type rgw  # 查看指定类型（如rgw）的进程
ceph orch ls --service-type rgw --export > rgw_spec_current.yaml  # 导出RGW服务配置
```

### mgr模块管理
```bash
ceph mgr module ls
ceph mgr module disalbe <module_name>
ceph mgr module enable <module_name>
```

## 二、OSD 与 PG 相关操作

### OSD 状态与结构
```bash
ceph osd stat            # 简洁显示OSD状态
ceph osd df              # 查看OSD磁盘使用情况
ceph osd df tree         # 以树形结构展示OSD容量分布
ceph osd tree            # 查看OSD的CRUSH层级结构
ceph osd status          # 详细显示OSD状态，读写 OPS
ceph osd perf    # osd 性能，延迟是否高
```

### OSD 运维相关
```bash
ceph orch osd rm status  # 检查是否有OSD正在被移除
ceph osd pool autoscale-status  # 查看pool是否开启PG自动调整
ceph osd  pool application get rbd-pool # 查看类型
ceph osd metadata osd.<id>  # 查看osd元数据，可以知道是哪个物理盘
ceph osd map ssd-pool test-object # 测试对象会放在池子的哪个pg和osd上
```

### PG（Placement Group）状态
```bash
ceph pg stat             # 简洁显示PG总体状态
ceph pg dump pgs_brief  # 查看所有pg，其中pg_stat, 第一个就是pool_id, 比如7.a，其中7就是pool_id 值
ceph pg dump pgs_brief | grep incomplete  # 查看incomplete状态的PG
ceph pg dump_stuck       # 查看卡住（stuck）的PG（含incomplete等状态）
ceph pg <pg.id> query | grep state -A 10  # 查看指定PG的状态（如：ceph pg 19.14 query | grep state -A 10）
ceph pg <pg.id> query | grep recovery_state -A 50  # 查看指定PG的恢复状态
```

### PG 分布与对象数量
```bash
# 列出对象数量最多的10个PG
ceph pg dump | awk '/^pg_stat/ { col=1; while($col!="osd") {col++}; col++ } /^[0-9a-f]+\.[0-9a-f]+/ { print $1, $(col) }' | sort -nk2 | tail -n 10
```

## 三、存储池（Pool）与容量管理

```bash
ceph df                  # 查看集群整体容量及各pool使用情况
rados df                 # 更详细的存储容量统计
ceph osd pool stats      # 查看所有pool的统计信息
ceph osd pool stats <pool-name>  # 查看指定pool的使用量
ceph osd dump # 检查池子的配置
ceph osd pool get <pool> all # 查看池子配置信息
ceph osd map <pool> <object> # 对象所在的物理位置
ceph osd pool get-quota public-fs-data0  # 查看池子的配额， set-quota 就是设置
```

```bash
# rados 相关操作
rados -p rdb-pool ls
rados -p rdb-pool put <object> <file>
rados -p rdb-pool get <object> <dest_file>
rados -p rdb-pool rm <object>
```

## 四、文件系统（CephFS）相关

### MDS（元数据服务器）状态
```bash
ceph fs ls
ceph fs status
ceph mds stat            # 查看MDS状态
ceph fs status public-fs      # 查看指定文件系统（如public-fs ）的状态
ceph tell mds.<name> damage ls # 查看详细的元数据损坏列表
```

### 用户权限管理
```bash
ceph auth get-or-create client.fsuser # 创建
ceph auth get client.fsuser  # 查看指定用户（如fsuser）的权限
ceph auth caps client.fsuser <权限>  # 更新用户权限（如：ceph auth cap client.fsuser xxx）
```

### 获取子卷
```bash
ceph fs subvolumegroup ls public-fs  # 列出子卷组
ceph fs subvolume ls public-fs --group_name manual # 列出特定组下的子卷
ceph fs subvolume getpath public-fs db-backup-0 --group_name manual # 取绝对路径
```

## 五、块存储（RBD）相关

```bash
rbd showmapped           # 查看已映射的RBD镜像
rbd map <pool>/<image> # 映射块到本机
rbd unmap /dev/rbd0 # 取消映射

rbd ls -p rbd-pool  # 列出所欲image
rbd du -p rbd-pool  # 取所有image的大小和使用量
```

## 六、对象存储（RGW）相关

```bash
radosgw-admin user list   # 查看RGW用户列表
radosgw-admin sync status  # 查看RGW同步状态
radosgw-admin user list --rgw-realm=s3-pool
radosgw-admin realm get --rgw-realm=s3-dev-pool
radosgw-admin zonegroup get --rgw-realm=s3-dev-pool --rgw-zonegroup=s3-dev-pool
radosgw-admin zone get --rgw-zone=s3-dev-pool --rgw-realm=s3-dev-pool
radosgw-admin bucket stats --rgw-realm=s3-dev-pool --bucket=test-bucket # 查看桶信息, shard
```

## 七、CRUSH 管理
```bash
ceph osd crush tree  # 查看 CRUSH 树结构
ceph osd crush tree --show-shadow # 更详细的
ceph osd crush rule ls  # 查看所有crush_rule
ceph osd crush rule dump <rule_name>  # 查看特定规则的详细
ceph osd crush rule dump | grep "rule" # 简单查看对应rule_id 对应关系
ceph osd pool get <pool> crush_rule # 查看特定pool使用的是什么规则

ceph osd crush class ls # 列出设备类
```

## 八、核心组件状态汇总

```bash
ceph pg stat             # PG状态汇总
ceph osd stat            # OSD状态汇总
ceph mon stat            # Mon节点状态汇总/
ceph mgr stat            # MGR（管理节点）状态汇总
ceph fs status
```
## 九 权限相关
```bash
ceph auth list # 查看所有用户的摘要
ceph auth get client.share # 查看用户的所有权限和密钥
ceph auth get-key client.share # 仅提取密钥（不显示权限）
ceph auth get client.share -o /etc/ceph/ceph.client.share.keyring # 以 keyring 格式输出（可直接写入文件）
```

## 十、告警相关
```bash
ceph crash archive-all # 消除告警 daemons have recently crashed 
```

## CRUSH规则配置

### 查看规则

```Markdown
# 查看已有 CRUSH 规则
ceph osd crush rule ls
```

### 新增 CRUSH rule

#### 复制副本池（replicated pool）

假设你有两类设备（ssd、hdd），想建一个 **只放在 ssd 上的规则**：

```Bash
ceph osd crush rule create-replicated ssd_rule default host ssd
```

参数解释：

- **ssd_rule** → 新规则名字
- **default** → 根 bucket（root），默认是 `default`，也可以用 `ssd-root`
- **host** → 副本分布层级（副本至少跨 host 分布）
- **ssd** → CRUSH bucket 名，表示选择 ssd 标签的设备
#### EC 规则（erasure-coded pool）

如果你要建 EC 池，先定义 profile：

```Bash
ceph osd erasure-code-profile set ec42 k=4 m=2
```

再建 EC 规则：

```Bash
ceph osd crush rule create-erasure ec42_rule ec42
```

### 修改 CRUSH 规则

如果你只是想 **调整现有规则的层级/类型**：

```Bash
ceph osd crush rule rm old_rule
ceph osd crush rule create-replicated new_rule <root> <failure-domain>
```

或者直接编辑 CRUSH map：

```Bash
ceph osd getcrushmap -o crushmap.bin
crushtool -d crushmap.bin -o crushmap.txt
vim crushmap.txt   # 修改规则
crushtool -c crushmap.txt -o newcrushmap.bin
ceph osd setcrushmap -i newcrushmap.bin
```

> ⚠ 注意：直接改 CRUSH map 是危险操作，一般只在复杂拓扑（比如多机房）下才需要。

### 应用规则到 pool

新建 pool 时指定：

```Bash
ceph osd pool create fast_pool 128 128 replicated ssd_rule
```

已有 pool 修改：

```Bash
ceph osd pool set fast_pool crush_rule ssd_rule
```

### 验证

```Bash
ceph osd pool get fast_pool crush_rule
ceph osd map fast_pool test_object
```

可以看到对象分布在哪些 OSD。

### 示例场景

比如你有 3 台 VM，每台 2 块盘：

- 你想让 **CephFS 数据池** 放 SSD，
- **CephFS 元数据池** 放 HDD。
流程：

1. 给 OSD 打标签：
   ```Bash
   ceph osd crush set-device-class ssd osd.1
   ceph osd crush set-device-class hdd osd.2
   ```
2. 创建规则：
   ```Bash
   ceph osd crush rule create-replicated hdd_rule default host hdd
   ceph osd crush rule create-replicated ssd_rule default host ssd
   ```
3. 应用到 pool：
   ```Bash
   ceph osd pool set fs_metadata crush_rule hdd_rule
   ceph osd pool set fs_data crush_rule ssd_rule
   ```
4. 验证：
   ```Bash
   ceph osd pool get fs_data crush_rule
   ceph osd map fs_data obj1
   ```

## 故障处理

### modprob ceph

```Markdown
MountVolume.MountDevice failed for volume "pvc-f092bfc2-0513-4c4c-8c5c-24d01c87ca12" : rpc error: code = Internal desc = an error (exit status 1) occurred while running modprobe args: [ceph]
```

需要在节点上添加 `modprob ceph`
