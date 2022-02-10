---
title: Python subprocess 模块使用
date: 2022-02-10 09:03:57
tags:
- python
categories:
- 编程
- python
---

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



