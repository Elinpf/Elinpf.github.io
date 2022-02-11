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

- `run`
```
subprocess.run(args, *, stdin=None, input=None, stdout=None, stderr=None, capture_output=False, shell=False, cwd=None, timeout=None, check=False, encoding=None, errors=None, text=None, env=None, universal_newlines=None)
```

其中`args`必须使用数组的方式，所以经常使用`shlex.split()`来切割命令

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


- `getoutput`
```python
subprocess.getoutput(cmd)
```

例子:
```py
uid = subprocess.getoutput("id -u")
if uid != "0":
    print("must be run with root permissions")
```



