---
title: Huawei SSH 配置中 ssh user 和 AAA 的关系
date: 2021-12-13 11:13:05
tags:
- ssh
- aaa
categories:
- 数通
---

当我们配置华为的SSH的配置的时候，需要除了`local-user`的配置之外，还要加上`ssh user`这个命令，为什么有了`local-user`之后，还需要`ssh user`呢？

## SSH User 和 AAA 的关系

SSH 包含了 `stelnet` 和 `sftp`，所以虽然local-user配置了`service-type ssh`，但是设备还是不知道用户登录的是`stelnet`还是`sftp`，所以需要配置`ssh user`。


## SSH 完整登录配置

```
aaa 
 local-user root password cipher Root@123
 local-user root service-type telnet ssh 
 local-user root level 3
#
ssh user root
ssh user root authentication-type password
ssh user root service-type stelnet
```

这样就可以正常登录了

## ssh authentication-type default password

如果嫌麻烦，可以直接配置`authentication-type default password`，这条命令代替的是以下三条命令：
```
ssh user xxx
ssh user xxx authentication-type password
ssh user xxx service-type all
```

设备的逻辑顺序是：如果设备找不到`ssh user xxx`，则去找全局配置`ssh authentication-type default password`，如果能找到 `ssh user xxx`，则会根据`ssh user`的配置进行校验。


## V5 和 V8 设备的区别

`ssh authentication-type default password`命令在大多数V5版本中是需要手动配置的，在少数新版本V5设备和V8版本设备中是默认配置。

因此在V8版本的设备中，只需要在AAA视图下配置SSH用户即可实现SSH（stelnet）登录设备的功能，做成默认配置可防止漏配置`ssh user`导致的登录失败同时也可简化配置。
