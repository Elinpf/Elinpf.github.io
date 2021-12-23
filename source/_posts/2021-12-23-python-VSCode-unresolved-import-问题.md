---
title: python VSCode unresolved import 问题
date: 2021-12-23 10:29:46
tags:
- python
- vscode
categories:
- 编程
- python
---

## 问题描述

当使用以下结构的时候，测试无法获取到`src\pyaio`的模块路径
```plant
- src
|- pyaio
|-- __init__.py
|-- main.py

- tests
|- test_main.py
```

## 解决办法

问题的原因是vscode解释器无法找到路径，解决参考[这篇文章](https://www.pianshen.com/article/84501691762/)以及[微软官方解释](https://code.visualstudio.com/docs/python/environments#_use-of-the-pythonpath-variable)

加添`launch.json`文件

```json .vscode/launch.json
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: 当前文件",
            "type": "python",
            "request": "launch",
            "program": "${file}",
            "console": "integratedTerminal",
            // highlight-start
            "env": {"PYTHONPATH": "${workspaceRoot}"},
            "envFile": "${workspaceFolder}/.env"
            // highlight-end
        }
    ]
}
```

以及根目录下添加`.env`文件

```plant .env
PYTHONPATH=./src/pyaio
```
