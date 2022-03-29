---
title: Python 调用执行Shell命令
date: 2022-02-10 09:03:57
tags:
- python
categories:
- 编程
- python
---

## os.system

```py
os.system(cmd)
```

可以直接使用Shell命令，并回显。

## subprocess

`subprocess`模块允许启动一个新的进程，并连接到输入/输出/错误管道，从而获取返回值。

常用的方法有

### `run`
```
subprocess.run(args, *, stdin=None, input=None, stdout=None, stderr=None, capture_output=False, shell=False, cwd=None, timeout=None, check=False, encoding=None, errors=None, text=None, env=None, universal_newlines=None)
```

|         参数         |                           注释                            |
| :------------------: | :-------------------------------------------------------: |
|        `args`        | 必须使用数组的方式，所以经常使用`shlex.split()`来切割命令 |
|       `stdin`        |                         标准输入                          |
|       `input`        |  使用**字节**传递输入，如果text为True则可以为**字符串**   |
|       `stdout`       |                         标准输出                          |
|       `stderr`       |                       标准错误输出                        |
|   `capture_output`   |                      是否获取返回值                       |
|       `shell`        |                    执行指定的shell指令                    |
|        `cwd`         |                      指定运行的目录                       |
|      `timeout`       |       超时后杀死子进程并抛出 `TimeoutExpired` 异常        |
|       `check`        |    进程以非零码退出时，抛出 `CalledProcessError` 异常     |
|      `encoding`      |              指定编码，此时input可以为字符串              |
|       `errors`       |                         输出文本                          |
|        `text`        |                以 input 和 errors 输出文本                |
|        `env`         |                  dict 类型，提供环境变量                  |
| `universal_newlines` |                     等同于 text 参数                      |

例如：
```python
subprocess.run(shlex.split("tmux new-session -s TireFire_{} -n Main -c {} -d".format(hostname, cwd)))
```

此时只是启动一个新进程执行，并没有捕获输出

```py
subprocess.run(shell.split("ls -la"), capture_output=True, encoding='utf-8')
```
这样就可以再返回值里面获得`stdout`了

更简单的方式是使用`subprocess.getoutput`


### `getoutput`
```python
subprocess.getoutput(cmd)
```

例子:
```py
uid = subprocess.getoutput("id -u")
if uid != "0":
    print("must be run with root permissions")
```

## 在权限不足的时候如何使用 sudo

这个分两种情况，一种是直接执行，另外一种是希望后台另起进程执行。参考[这篇文章](https://stackoverflow.com/questions/567542/running-a-command-as-a-super-user-from-a-python-script)

### 直接执行

```py
subprocess.run(shlex.split(f"sudo -S {shell}"),
                shell=False)
```

这样就会提示需要 sudo 密码

### 后台执行

```py
passwd = getpass("Please enter your password: ")
passwd_proc = subprocess.Popen(shlex.split(
    f"echo {passwd}"), stdout=subprocess.PIPE)

subprocess.Popen(shlex.split(f"sudo -S {shell}" if sudo else shell),
                    shell=False,
                    stdin=passwd_proc.stdout,
                    stdout=output, stderr=output)
```

这种方式稍微绕一下，但是效果很好。


