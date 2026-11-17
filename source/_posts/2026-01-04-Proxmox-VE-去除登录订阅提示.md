---
title: Proxmox VE 去除登录订阅提示
date: 2026-01-04 15:36:06
tags:
- pve
- proxmox
categories:
- 运维
- 虚拟化
---

未购买订阅的 Proxmox VE 在登录 Web 界面时会弹出 "No valid subscription" 提示，每次都要手动关闭。下面记录去掉这个提示的方法。

> 本文方法仅建议用于个人实验环境；生产环境请购买订阅以获得官方支持。

## 操作步骤

1. 备份原文件：

```Bash
cd /usr/share/javascript/proxmox-widget-toolkit
cp proxmoxlib.js proxmoxlib.js.bak
```

2. 编辑 `proxmoxlib.js`，找到 `checked_command` 函数中处理订阅状态的位置，在 `let res = response.result;` 之后加一行：

```JavaScript
success: function (response, opts) {
    let res = response.result;
    res.data.status = 'active';   // 关键：直接标记为 active
    if (
```

3. 重启 `pveproxy` 服务：

```Bash
systemctl restart pveproxy.service
```

4. 浏览器可能有缓存，强制刷新或重新登录即可。

## 说明

- 升级 PVE 后 `proxmoxlib.js` 可能被覆盖，需要重新修改。
- 该修改只影响前端提示，不改变订阅状态。

## 回滚

需要恢复原状时，把备份文件覆盖回去并重启服务：

```Bash
cd /usr/share/javascript/proxmox-widget-toolkit
cp proxmoxlib.js.bak proxmoxlib.js
systemctl restart pveproxy.service
```
