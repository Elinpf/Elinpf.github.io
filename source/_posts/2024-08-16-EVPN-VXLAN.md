---
title: EVPN VXLAN
date: 2024-08-16 15:58:25
tags:
- vxlan
- evpn
categories:
- 数通
---

## 参考

- [EVPN技术白皮书-6W101-新华三集团-H3C](https://www.h3c.com/cn/Service/Document_Software/Document_Center/Home/Routers/00-Public/Learn_Technologies/White_Paper/EVPN_White_Paper-10897/)
- [01-EVPN配置-新华三集团-H3C](https://www.h3c.com/cn/d_201907/1217900_30005_0.htm)
- [64-EVPN+DRNI典型配置举例-新华三集团-H3C](https://www.h3c.com/cn/d_201907/1212905_30005_0.htm)
## 配置案例

- [EVPN小实验：集中式EVPN网关配置（上）-阿里云开发者社区](https://developer.aliyun.com/article/1170575?spm=a2c6h.27925324.detail.63.6b6c1813ns7nix)
- [EVPN小实验：集中式EVPN网关配置（下）-阿里云开发者社区](https://developer.aliyun.com/article/1170588?spm=a2c6h.27925324.detail.59.6b6c1813ns7nix)

```Markdown
# 有些型号的交换机需要调整 vxlan 资源类型
hardware-resource vxlan l3gw
```

## 实验

- 在实验中，BGP作为EVPN的协议载体，在建立Tunnel隧道的时候，只有Leaf节点相互建立的Tunnel隧道，但是和Spine，Spine上只有REG接口，并且SVI和SVI-interface都没有起来。这就导致了3层不通。
  - 二层也没有通，不清楚是配置问题还是模拟器的BUG，毕竟在手工VXLAN里面，也存在模拟器BUG
## 维护命令

```Markdown
# 查看EVPN自动发现的邻居信息
display evpn auto-discovery imet

# 查看vxlan模式的隧道
dis vxlan tunnel-interface
dis vxlan tunnel

# 查看vsi虚接口信息
display interface vsi-interface

# 查看vsi详细信息
display l2vpn vsi verbose

# 查看服务实例
dis l2vpn service-instance

# 查看VSI学习到的MAC地址表项
dis l2vpn mac-address

# 查看VSI的EVPN ARP表项
dis evpn route arp
dis arp

# 查看BGP l2vpn 对等体信息
dis bgp peer l2vpn evpn

# 查看l2vpn 路由信息
dis bgp l2vpn evpn

# 查看转发表
dis fib {ip}
```
