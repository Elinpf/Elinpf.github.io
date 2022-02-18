---
title: kali docker apt gpg 验证失败
date: 2022-02-18 09:59:58
tags:
- docker-kali
categories:
- 系统
- linux
---

## 错误信息

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

## 尝试1

```bash
apt-key adv --keyserver hkp://keys.gnupg.net --recv-keys ED444FF07D8D0BF6
```

但是新docker没有安装`gnupg`会报`E: gnupg, gnupg2 and gnupg1 do not seem to be installed, but one of them is required for this operation`错误。

要想安装`gnupg`则需要更新apt, 进入死循环

## 尝试2

强行获取密钥然后安装

方法是下载最新的`kali-archive-keyring`，由于无法使用apt，所以手动下载。
最新的到`http://http.kali.org/pool/main/k/kali-archive-keyring`查看

```bash
wget http://http.kali.org/pool/main/k/kali-archive-keyring/kali-archive-keyring_2022.1_all.deb
apt install ./kali-archive-keyring_2022.1_all.deb
```

由于docker-kali没有wget，只能在主机下载好后挂载到docker-kali上安装。

但其实官方的keyring已经是最新的了，这个尝试是无效的。

## 最终无奈的选择

因为原因是不能验证，那么就忽略验证就可以了

- 参考的是[这一篇讨论](https://askubuntu.com/questions/74345/how-do-i-bypass-ignore-the-gpg-signature-checks-of-apt)


创建`/etc/apt/apt.conf.d/99allow_unauth`文件并将`gpg-pubkey`设置为忽略
```bash
echo 'APT { Get { AllowUnauthenticated "1"; }; }; Acquire { AllowInsecureRepositories "1"; AllowDowngradeToInsecureRepositories "1"; };' > /etc/apt/apt.conf.d/99allow_unauth
```

此时就可以正常使用了，只不过会有`Warning`，这也是没办法的一个办法。