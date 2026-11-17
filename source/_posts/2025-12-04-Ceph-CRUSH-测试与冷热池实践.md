---
title: Ceph CRUSH 测试与冷热池实践
date: 2025-12-04 18:02:02
tags:
- ceph
- crush
- osd
categories:
- 运维
- Ceph
---

## 实验目标

- [x] crush相关创建和修改流程
- [x] osd加入和移除的标准化流程
- [x] 冷热分区部署流程

## OSD上下线流程

### 实验项确认

1. osd如何进行加入，保证在加入后不立即均衡
2. 加入后调整osd类型
3. 手动触发均衡
4. 测试文件写入
5. 正常驱逐OSD，并下线
6. 测试异常OSD下线

### 测试流程

- [Rook Ceph OSD异常，格式化osd硬盘重新挂载 - lswweb - 博客园](https://www.cnblogs.com/lswweb/p/13895160.html)

```Bash
ceph osd status  # 查看一下状态

# 标记暂停数据均衡和osd导入导出
ceph osd set norebalance
ceph osd set norecover
ceph osd set nobackfill
ceph osd set nodown
ceph osd set noup

# 测试调整了权重
# ceph osd crush reweight osd.3 0  # 一般不调整，由rook维护
ceph osd reweight osd.3 0  # 运行时调整权重，会将pg都驱逐掉，数据掉为0，默认是1

ceph osd unset norebalance
ceph osd unset norecover
ceph osd unset nobackfill
ceph osd unset nodown
ceph osd unset noup

# 测试osd的in 和 out

# 下线的标准做法
# 标准做法 reweight + out。但其实，只需要设置为out就可以了，reweight=0是自动完成的
root@ceph-1:/var/lib/ceph# ceph osd out osd.3
osd.3 is already out. 

# 永久移除 osd
# 1. 关闭operator
# 2. 保证osd上pg数量为0
# 然后
ceph osd crush remove osd.3
ceph auth del osd.3
# 清理掉osd 的deployment，然后
ceph osd rm 3
# 此时就看不到osd了，最后清理cephcluster中的osd配置

# 添加 osd
# 先添加 noup flag，避免立即均衡
# reweight调整为0，但是当取消 noup 标记后，会立即reweight调整为1
# 所以此操作是无效的
# 就是要等准备均衡时，移除flag即可

```

## 设计实验
- 设备关机检修，pg 不迁移
- 加盘 + 关机重启

## 添加3台设备的osd
我在添加的时候,发现,即使调整为 osd down, pg仍然准备remapped?
是我这个的特例吗? 重新试一下,在此之前

**尝试格式化一个磁盘**：
发生了什么!
我格式化osd.5,然后等了半天,发现ceph -s 没有发现这个osd出现问题,df中也同样标记这个osd为up,无法主动判断是否异常
此时我手动在 k8s中将 osd.5 重启了下,然后osd.5就无法启动了
此时 osd.5 会被标记为 down,但是由于不是out,所以还是显示存在pg,但其实此时磁盘上已经被清空了
这时候有两个方案
1. 等着10分钟,等osd失效,然后rook会拉起一个新osd.6, 来代替osd.5(推荐等待)
2. reweight 调整为0,主动迁移

然后后面就正常删除 osd.5 即可

## 当一个osd down的时候, 会发生什么
osd 中会变成 down,但是状态还是in, pg变为0, 但是不会进行均衡(因为 reweight=1), 减掉的pg变为 undersized

## 尝试调整reweight为0
调整为0后, 会立即进行均衡

## 调整CRUSH规则

### 调整osd类型

```Bash
ceph osd crush rm-device-class osd.6  # (可选)删除原有类型
ceph osd crush set-device-class ssd osd.6  # 设定新类型

# 调整前
root@ceph-1:~# ceph osd crush tree --show-shadow
ID  CLASS  WEIGHT   TYPE NAME          
-2    hdd  0.11691  root default~hdd   
-4    hdd  0.03897      host ceph-2~hdd
 0    hdd  0.01949          osd.0      
 3    hdd  0.01949          osd.3      
-6    hdd  0.03897      host ceph-3~hdd
 1    hdd  0.01949          osd.1      
 4    hdd  0.01949          osd.4      
-8    hdd  0.03897      host ceph-4~hdd
 2    hdd  0.01949          osd.2      
 6    hdd  0.01949          osd.6      
-1         0.11691  root default       
-3         0.03897      host ceph-2    
 0    hdd  0.01949          osd.0      
 3    hdd  0.01949          osd.3      
-5         0.03897      host ceph-3    
 1    hdd  0.01949          osd.1      
 4    hdd  0.01949          osd.4      
-7         0.03897      host ceph-4    
 2    hdd  0.01949          osd.2      
 6    hdd  0.01949          osd.6  
 
 # 调整后
 root@ceph-1:~# ceph osd crush tree --show-shadow
ID   CLASS  WEIGHT   TYPE NAME          
-12    ssd  0.05846  root default~ssd   
 -9    ssd  0.01949      host ceph-2~ssd
  3    ssd  0.01949          osd.3      
-10    ssd  0.01949      host ceph-3~ssd
  4    ssd  0.01949          osd.4      
-11    ssd  0.01949      host ceph-4~ssd
  6    ssd  0.01949          osd.6      
 -2    hdd  0.05846  root default~hdd   
 -4    hdd  0.01949      host ceph-2~hdd
  0    hdd  0.01949          osd.0      
 -6    hdd  0.01949      host ceph-3~hdd
  1    hdd  0.01949          osd.1      
 -8    hdd  0.01949      host ceph-4~hdd
  2    hdd  0.01949          osd.2      
 -1         0.11691  root default       
 -3         0.03897      host ceph-2    
  0    hdd  0.01949          osd.0      
  3    ssd  0.01949          osd.3      
 -5         0.03897      host ceph-3    
  1    hdd  0.01949          osd.1      
  4    ssd  0.01949          osd.4      
 -7         0.03897      host ceph-4    
  2    hdd  0.01949          osd.2      
  6    ssd  0.01949          osd.6 
```

可以看到多了个 `default~ssd`

### 调整crush的bucket结构

桶结构类型：root > datacenter > rack > host > osd

```Bash
# 创建 SSD 专用的 root bucket
ceph osd crush add-bucket ssd-root root

# 创建主机 bucket（如已存在可跳过）
ceph osd crush add-bucket serverc-ssd host

# 将 host 移动到 ssd-root 下
ceph osd crush move serverc-ssd root=ssd-root

# 将 osd 移动到 serverc-ssd 这个host下(如果没有这个host,会自动创建)
ceph osd crush move osd.3 host=serverc-ssd

# (可选)删除命令
ceph osd crush rm ceph-2-ss

# 调整完后
root@ceph-1:~# ceph osd crush tree
ID   CLASS  WEIGHT   TYPE NAME           
-13         0.05846  root ssd-root       
-14         0.05846      host serverc-ssd
  3    ssd  0.01949          osd.3       
  4    ssd  0.01949          osd.4       
  6    ssd  0.01949          osd.6       
 -1         0.05846  root default        
 -3         0.01949      host ceph-2     
  0    hdd  0.01949          osd.0       
 -5         0.01949      host ceph-3     
  1    hdd  0.01949          osd.1       
 -7         0.01949      host ceph-4     
  2    hdd  0.01949          osd.2    
```

此时对应的osd的pg也会进行迁移,因为原本的rule已经不包含现在的osd了

### 添加自定义Crush Rule

```Markdown
# 创建 SSD 专用规则（3副本，跨 host 分布）
ceph osd crush rule create-replicated ssd-rule ssd-root host

# 查看生成的规则
ceph osd crush rule dump ssd-rule

root@ceph-1:~# ceph osd crush rule dump ssd-rule
{
    "rule_id": 25,
    "rule_name": "ssd-rule",
    "type": 1,
    "steps": [
        {
            "op": "take",
            "item": -13,
            "item_name": "ssd-root"
        },
        {
            "op": "chooseleaf_firstn",
            "num": 0,
            "type": "host"
        },
        {
            "op": "emit"
        }
    ]
}
```

### 创建pool

```Markdown
# 创建池并指定 CRUSH 规则
ceph osd pool create ssd-pool 8 8 replicated ssd-rule

# 查看池配置
ceph osd pool get ssd-pool crush_rule

# 调整池的CRUSH规则
ceph osd pool set ssd-pool crush_rule <dest_crush_rule>
```

### 导出crushmap

```Bash
apt install ceph-base -y
ceph osd getcrushmap -o crushmap.bin
crushtool -d crushmap.bin -o crushmap.txt  
```

### 测试存放位置

```Bash
root@ceph-1:~# ceph osd map ssd-pool test-object
osdmap e3214 pool 'ssd-pool' (35) object 'test-object' -> pg 35.bf8f6aea (35.a) -> up ([4], p4) acting ([4,0,1], p4)
```

可以看到, 此时其实只有一个host, 所以故障域没有区分开, 只有一个OSD是up的

### 当一个osd down的时候, 会发生什么

osd 中会变成 down,但是状态还是in, pg变为0, 但是不会进行均衡(因为 reweight=1), 减掉的pg变为 undersized

## 冷热盘分离调度

点击链接查看和 Kimi 的对话 [https://www.kimi.com/share/19b8bce2-fa52-81ff-8000-0000573f3b83](https://www.kimi.com/share/19b8bce2-fa52-81ff-8000-0000573f3b83)

### 创建冷盘池

```Bash
# 创建冷池
ceph osd crush rule create-replicated s3-dev-pool.rgw.buckets.cold-data ssd-root host
ceph osd pool create s3-dev-pool.rgw.buckets.cold-data 8 8 replicated s3-dev-pool.rgw.buckets.cold-data
ceph osd pool application enable s3-dev-pool.rgw.buckets.cold-data rgw
```

or

```YAML
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: "s3-dev-pool.rgw.buckets.cold-data"
  namespace: rook-ceph
spec:
  application: "rgw"
  erasureCoded:
    codingChunks: 0
    dataChunks: 0
  failureDomain: host
  crushRoot: "hdd-root"
  deviceClass: "hdd"
  mirroring: {}
  quotas: {}
  replicated:
    size: 3
  statusCheck:
    mirror: {}
```

### 错误方式绑定冷池（是错误的，留存）

待删除，不应该新建 placement-id

```Markdown
# 创建cold-placement并绑定
radosgw-admin zonegroup placement add \
  --rgw-realm s3-dev-pool \
  --rgw-zonegroup s3-dev-pool \
  --placement-id cold-placement \
  --data-pool s3-dev-pool.rgw.buckets.cold-data \
  --index-pool s3-dev-pool.rgw.buckets.cold-data  \
  --data-extra-pool default.rgw.buckets.non-ec
  

# 为cold-placement添加COLD存储类
radosgw-admin zonegroup placement add \
  --rgw-realm s3-dev-pool \
  --rgw-zonegroup s3-dev-pool \
  --placement-id cold-placement \
  --storage-class COLD

# 提交配置
radosgw-admin period update --commit --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool

# 验证配置
## zonegroup 中是看不到 placement 的 data-pool
radosgw-admin zonegroup get --rgw-realm s3-dev-pool --rgw-zonegroup=s3-dev-pool

## 在 zone 中查看
radosgw-admin zone get --rgw-zone=s3-dev-pool --rgw-realm=s3-dev-pool
radosgw-admin zonegroup  placement list --placement-id default-placement --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool
```

```Markdown
# 2.1 创建 COLD 存储类
radosgw-admin zone placement add \
  --rgw-realm s3-dev-pool \
  --rgw-zonegroup s3-dev-pool \
  --rgw-zone s3-dev-pool \
  --placement-id cold-placement \
  --storage-class COLD \
  --data-pool s3-dev-pool.rgw.buckets.cold-data \
  --index-pool s3-dev-pool.rgw.buckets.cold-index

# 2.2 提交配置
radosgw-admin period update --commit --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool

# 验证
# 3.1 查看 Zone 配置（这才是完整信息）
radosgw-admin zone get --rgw-zone=s3-dev-pool

# 3.2 确认默认 placement 是热池
radosgw-admin zonegroup get --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool | grep default_placement
# 应该输出："default_placement": "default-placement"

# 3.3 检查周期信息是否提交
radosgw-admin period get --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool

# 3.4 查看特定 placement 的详细信息
radosgw-admin zone placement get \
  --rgw-zone=s3-dev-pool \
  --placement-id=default-placement

radosgw-admin zone placement get \
  --rgw-zone=s3-dev-pool \
  --placement-id=cold-placement \
  --storage-class=COLD
```

### 绑定冷池（验证成功）

配置zone和zonegroup的 placement_target

```Markdown
# 1. 为 default-placement 添加 COLD 存储类声明
radosgw-admin zonegroup placement add \
  --rgw-realm s3-dev-pool \
  --rgw-zonegroup s3-dev-pool \
  --placement-id default-placement \
  --storage-class COLD

# 检查一下 zonegroup
radosgw-admin zonegroup get --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool
# 你应该能看到 default-placement 下面有了 storage_classes: [STANDARD, COLD]

# 2. 为 COLD 类绑定具体的 Data Pool
# 注意：Storage Class 通常共用 Index Pool，只需要指定 Data Pool
radosgw-admin zone placement add \
  --rgw-realm s3-dev-pool \
  --rgw-zonegroup s3-dev-pool \
  --rgw-zone s3-dev-pool \
  --placement-id default-placement \
  --storage-class COLD \
  --data-pool s3-dev-pool.rgw.buckets.cold-data \
  --compression lz4  # (可选) 冷数据通常建议开启压缩
  
# 提交更改
radosgw-admin period update --commit --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool

# 检查zone
radosgw-admin zone get --rgw-zone=s3-dev-pool

#  查看特定 placement 的详细信息
radosgw-admin zone placement get \
  --rgw-zone=s3-dev-pool \
  --placement-id=default-placement
```

### s3 周期

- 先创建一个测试用的桶
```Bash
rclone mkdir s3-dev-pool:/test-lifecycle
```

- 编写个生命周期的策略
```JSON
cat > lifecycle.json <<EOF
{
  "Rules": [
    {
      "ID": "move-to-cold-after-30d",
      "Status": "Enabled",
      "Filter": {},
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "COLD"
        }
      ],
      "Expiration": {  // 删除周期
        "Days": 365
      }
    }
  ]
}
EOF
```

- 使用 awscli 来配置生命周期，以及查看
```Bash
# 太长了，简化下
alias awsep="aws --endpoint-url http://10.0.0.241:32002 --no-verify-ssl"
# 如果是https
alias awsep="aws --endpoint-url https://s3-dev-pool.example.com"
alias awsep="aws --endpoint-url https://s3-prod-pool.example.com --profile s3-prod-pool"

# 配置生命周期
awsep s3api put-bucket-lifecycle-configuration \
  --bucket test-lifecycle \
  --lifecycle-configuration file://lifecycle.json
  
# 验证配置
awsep s3api get-bucket-lifecycle-configuration \
  --bucket test-lifecycle 

# 查看所有桶的生命周期进度
radosgw-admin --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool lc list

# 查看特定桶的详情
radosgw-admin --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool lc get --bucket=test-lifecycle
```

### 测试方案

使用1day +手动执行的方式

```Markdown
# 配置生命周期
awsep s3api put-bucket-lifecycle-configuration \
  --bucket test-lifecycle-1day \
  --lifecycle-configuration file://test-lifecycle-1day.json

# 验证配置
awsep s3api get-bucket-lifecycle-configuration \
  --bucket test-lifecycle-1day
  
# 生成测试文件
dd if=/dev/urandom of=test-file-50k bs=1K count=50

# 复制到桶
rclone copy test-file-50k s3-dev-pool:/test-lifecycle-1day/

# 手动触发生命周期处理， 但是如果时间没有到还是不会迁移的
radosgw-admin --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool \
  lc process \
  --bucket=test-lifecycle-1day \
  --include-all
  
# 查看池子里面是否有内容
rados ls --pool=s3-dev-pool.rgw.buckets.cold-data | grep test-file-50k
```

```Markdown
# 使用debug模式来手动触发执行
radosgw-admin lc process --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool --bucket=test-lifecycle-1day --debug-rgw=20 
```

有几个注意点要明确：

1. Zonegroup 是逻辑层，定义了有哪些placement_target
   1. 一个桶只会走一个placement_target
   2. StorageClass是Target内部标签，默认是`STANDARD`，可以再添加
2. Zone是定义了逻辑具体如何映射到pool中的，也就是在zone里面去定义`--data-pool`

### 删除清理方法

```Markdown
# 从 zonegroup 删除 placement target
radosgw-admin zonegroup placement rm \
  --rgw-realm s3-dev-pool \
  --rgw-zonegroup s3-dev-pool \
  --placement-id cold-placement

# 从 zone 删除对应的 placement pools（如果有）
radosgw-admin zone placement rm \
  --rgw-realm s3-dev-pool \
  --rgw-zone s3-dev-pool \
  --placement-id cold-placement
  
# 删除生命周期的配置
awsep s3api delete-bucket-lifecycle \
  --bucket test-lifecycle-1day
```

### 迁移后的现象

```Bash
POOL                                ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
s3-dev-pool.rgw.buckets.data        30   32      0 B        2      0 B      0     23 GiB
s3-dev-pool.rgw.buckets.cold-data   43   32  150 KiB        2  456 KiB      0     19 GiB

root@ceph-1:~/rgw_lifecycle# rclone ls s3-dev-pool:
   102400 test-lifecycle/test-file-100k
    51200 test-lifecycle-1day/test-file-50k
    

root@ceph-1:~/rgw_lifecycle# rados ls --pool=s3-dev-pool.rgw.buckets.data
dd8337b8-686f-4aec-8230-c9de690de842.3532553.1_test-file-50k
dd8337b8-686f-4aec-8230-c9de690de842.3873882.1_test-file-100k

root@ceph-1:~/rgw_lifecycle# rados ls --pool=s3-dev-pool.rgw.buckets.cold-data
dd8337b8-686f-4aec-8230-c9de690de842.3873882.1__shadow_.1c3DFQaUmX3Bbkzx9Mxnme5RCbBPg_z_0
dd8337b8-686f-4aec-8230-c9de690de842.3532553.1__shadow_.Hk-0z7LUfa-N6_2wOGvpSnV51zFYenZ_0

# 查看对象的storage_class 
root@ceph-1:~# radosgw-admin object stat   --bucket=test-lifecycle-1day   --object=test-file-50k --rgw-realm s3-dev-pool --rgw-zonegroup s3-dev-pool 
...
    "attrs": {
        "user.rgw.content_type": "application/octet-stream",
        "user.rgw.storage_class": "COLD",
        "user.rgw.tail_tag": "_058pTUVn2i0ekPcJY6Q2hPDSBfgyrSK",
        "user.rgw.x-amz-acl": "private",
        "user.rgw.x-amz-content-sha256": "UNSIGNED-PAYLOAD",
        "user.rgw.x-amz-date": "20260105T024318Z",
        "user.rgw.x-amz-meta-mtime": "1767580966.239999143"
    }
```

从池子中可以看到 data 池是两个0字节的对象，而cold-data池中是正常大小的两个重命名后的对象

为什么会这样：

1. 这是生命周期迁移的标准动作
2. 将用户数据块复制到冷池中，并且根据规则重命名
3. 将原对象截断为0直接的影子对象
4. 从索引中，将stroage_class 改到了 COLD里面
**「生命周期迁移」= 数据块复制到新池 + 原对象变零字节影子 + 索引里改存储类；**
