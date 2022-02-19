---
title: kali docker 使用时遇到的坑
date: 2022-02-18 10:03:04
tags:
- docker-kali
categories:
- 系统
- linux
---

## 安装官方的 Docker Kali GPG 无法验证

在使用2022.1版本 kalilinux/kali-rolling 的时候，apt update 会报以下验证错误。

```
root@28593cafb270:/# apt update
Get:1 http://mirrors.neusoft.edu.cn/kali kali-rolling InRelease [30.6 kB]
Err:1 http://mirrors.neusoft.edu.cn/kali kali-rolling InRelease
  The following signatures couldn't be verified because the public key is not available: NO_PUBKEY ED444FF07D8D0BF6
Reading package lists... Done
W: http://http.kali.org/kali/dists/kali-rolling/InRelease: The key(s) in the keyring /etc/apt/trusted.gpg.d/debian-archive-bullseye-automatic.gpg are ignored as the file is not readable by user '_apt' executing apt-key.
...
W: GPG error: http://mirrors.neusoft.edu.cn/kali kali-rolling InRelease: The following signatures couldn't be verified because the public key is not available: NO_PUBKEY ED444FF07D8D0BF6
E: The repository 'http://http.kali.org/kali kali-rolling InRelease' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
```

解决办法前往[](!kali-docker-apt-gpg-验证失败)