---
title: VirtualBox 与 Hper-V 互斥的问题，导致HCL无法启动设备
date: 2023-06-12 12:43:37
tags:
- debug
categories:
- 数通
---

遇到问题记录一下，以后再遇到就不用再去查了。

在使用华三模拟器的时候，发现无法启动设备。

检查发现在VBox里面，他新建了`Simware_Base`这个虚拟机，但是无法启动，报错如下：

```bash
Call to WHvSetupPartition failed: ERROR_SUCCESS (Last=0xc000000d/87) (VERR_NEM_VM_CREATE_FAILED).
```

在网上查了一下，发现是因为Hyper-V和VBox的互斥问题，解决办法是禁用Hyper-V。

- [相同问题的文章](https://superuser.com/questions/1502529/call-to-whvsetuppartition-failed-error-success-last-0xc000000d-87-verr-nem-v)

```
bcdedit /set hypervisorlaunchtype off
```

但是我发现其实可以不用将Hyper-V禁用，只需要修改一下ViretualBox的配置就可以了。

- [参考这篇文章](https://forums.virtualbox.org/viewtopic.php?f=6&t=90853&start=120)

在 `%userprofile%\.VirtualBox\VirtualBox.xml` 中的`ExtraDataItem`中添加如下配置即可：

```  %userprofile%\.VirtualBox\VirtualBox.xml
<ExtraDataItem name="VBoxInternal/NEM/UseRing0Runloop" value="0"/>
```