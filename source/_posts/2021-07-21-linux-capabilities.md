---
title: Linux Capabilities
date: 2021-07-21 09:58:47
tags:
- 提权
- linux
categories:
- 渗透
---

## 什么是Capabilities

Capabilites是从内核2.5之后引入的，作用于**进程**或者**线程**上，是将权限更加细致的划分，保障系统安全的一种能力。
类似于windows的特权。


## capabilities set

```
root@iZbp19p0eesh0lxr45we33Z:~# cat /proc/$$/status | grep Cap
CapInh: 0000000000000000  # 可以继承的CAP(i)
CapPrm: 0000003fffffffff  # 可以使用的CAP(p)
CapEff: 0000003fffffffff  # 使用的CAP(e)
CapBnd: 0000003fffffffff  # 可以被禁止的
CapAmb: 0000000000000000  # 
```


## 进程CAP

- 查看进程CAP

```
cat /proc/1234/status | grep Cap  # 查看1234进程的能力
cat /proc/$$/status | grep Cap # 查看现在进程的能力
```

- 解码CAP

```
capsh --decode=0000000000003000
0x0000000000003000=cap_net_admin,cap_net_raw
```

## 二进制文件CAP

- 查看二进制文件CAP

```
getcap /usr/bin/ping
getcap `whereis python3`
```

- 搜索所有二进制文件的CAP

```
getcap -r / 2>null
```

# 如何利用

根据不同的CAP找出对应的提权方法，详细方法在[这里查看](https://book.hacktricks.xyz/linux-unix/privilege-escalation/linux-capabilities#malicious-use)


|             CAP             |               描述               | 能否提权 |
| :-------------------------: | :------------------------------: | :------: |
|        CAP_SYS_ADMIN        |         可以挂在文件系统         |    √     |
|       CAP_SYS_PTRACE        |   可以shellcode注入并逃离容器    |    √     |
|       CAP_SYS_MODULE        |     可以增加或者移除核心模块     |    √     |
|     CAP_DAC_READ_SEARCH     | 可以绕过查看文件和执行文件的检查 |    √     |
|      CAP_DAC_OVERRIDE       |            写任意文件            |    √     |
|          CAP_CHOWN          |       更改任意文件的所有者       |    √     |
|         CAP_FORMER          |        更改任意文件的权限        |    √     |
|         CAP_SETUID          |           设置有效用户           |    √     |
|         CAP_SETGID          |            设置有效组            |    √     |
|         CAP_SETFCAP         |    可以设置文件或者进程的CAP     |    √     |
|          CAP_KILL           |         可以杀死任何进程         |    ×     |
|    CAP_NET_BIND_SERVICE     |         可以监听任何端口         |    ×     |
|         CAP_NET_RAW         |           可以嗅探接口           |    ×     |
| CAP_NET_ADMIN + CAP_NET_RAW |        可以修改防护墙规则        |    ×     |
|     CAP_LINUX_IMMUTABLE     |          修改inode属性           |    ×     |


## 案例

### python 拥有 CAP_SETUID

![](1.png)




