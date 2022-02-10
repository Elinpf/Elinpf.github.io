---
title: linux 防火墙 IPTABLE
date: 2021-12-31 16:15:35
tags:
categories:
- 渗透
- 知识点
---

## 概述

iptable 其实是netfilter的对外接口，内核防火墙其实是netfilter

iptable 有链和表的概念，还有包处于什么位置

![](1.png)

这就是iptable的运行图，有5个链：
`prerouting` `forwording` `postrouting` `input` `output`


有4个基本表：
`raw` `mangle` `nat` `filter`

```
filter表：负责过滤功能，防火墙；内核模块：iptables_filter

nat表：network address translation，网络地址转换功能；内核模块：iptable_nat

mangle表：拆解报文，做出修改，并重新封装 的功能；iptable_mangle

raw表：关闭nat表上启用的连接追踪机制；iptable_raw
```

## 匹配规则

匹配规则分为标准匹配和扩展匹配，也就是基于IP和基于端口的匹配


## 动作

```
ACCEPT：允许数据包通过。

DROP：直接丢弃数据包，不给任何回应信息，这时候客户端会感觉自己的请求泥牛入海了，过了超时时间才会有反应。

REJECT：拒绝数据包通过，必要时会给数据发送端一个响应的信息，客户端刚请求就会收到拒绝的信息。

SNAT：源地址转换，解决内网用户用同一个公网地址上网的问题。

MASQUERADE：是SNAT的一种特殊形式，适用于动态的、临时会变的ip上。

DNAT：目标地址转换。

REDIRECT：在本机做端口映射。

LOG：在/var/log/messages文件中记录日志信息，然后将数据包传递给下一条规则，也就是说除了记录以外不对数据包做任何其他操作，仍然让下一条规则去匹配。
```

## 命令

- 查看

	- `iptables -L` 默认就是查看filter 表的 INPUT 链
	- `iptables -nvL INPUT --line-numbers`  查看详情

- [这里](http://blog.51yip.com/linux/1404.html)是iptables 的增删改查命令

清除计数为`-Z`