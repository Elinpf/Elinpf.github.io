---
title: vscode Debug justMyCode
date: 2022-03-07 10:14:51
tags:
- vscode
categories:
- 编程
- python
---

在debug和pytest debug中添加 `justMyCode` 选项

- 参考这个[issue](https://github.com/microsoft/vscode-python/issues/7083)

```json .vscode/launch.json
{
    "name": "Python: 当前文件",
    "type": "python",
    "request": "launch",
    "program": "${file}",
    "console": "integratedTerminal",
    // highlight-next-line
    "justMyCode": false
},
// highlight-start
{
    "name": "Debug Pytest",
    "type": "python",
    "request": "test",
    "justMyCode": false
}
// highlight-end



