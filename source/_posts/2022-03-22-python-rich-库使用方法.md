---
title: python rich 库使用方法
date: 2022-03-22 17:26:11
tags:
- python
- todo
categories:
- 编程
- python
---

## 模块

使用`python3 -m rich.<module>`这样的形式可以看到官方给出的一些例子，可以演示的模块有：

|       模块       |                                    说明                                    |
| :--------------: | :------------------------------------------------------------------------: |
|     `align`      |                                    定位                                    |
|      `box`       |                                  box 效果                                  |
|     `color`      |                                  色彩定义                                  |
|    `columns`     |                                   定义列                                   |
|    `console`     |                                 高层级接口                                 |
| `default_styles` |                                  默认样式                                  |
|    `diagnose`    |                                    诊断                                    |
|     `emoji`      | 输出所有表情，使用方式可以直接把表情粘贴过来，或者`:<emoji_name>:`这种方式 |
|  `highlighter`   |                                    高亮                                    |
|      `json`      |                               Json 格式输出                                |
|     `layout`     |                                  布局效果                                  |
|      `live`      |                        渲染长期存活，自动更新的事件                        |
|    `logging`     |                                  日志输出                                  |
|    `markdown`    |                             Markdown 格式输出                              |
|     `markup`     |                            演示几种打标签的方式                            |
|    `padding`     |                             演示padding的用法                              |
|     `pager`      |                               演示页面的用法                               |
|    `palette`     |    输出一个调色板，其实这里的示例告诉了你如何自定义一个可以被渲染的类。    |
|     `panel`      |                            如何定义一个面板单元                            |
|     `pretty`     |                               漂亮的变量输出                               |
|  `progress_bar`  |                                   进度条                                   |
|    `progress`    |                              使用进度条的例子                              |
|     `prompt`     |                                 输入提示符                                 |
|      `repr`      |                                  描述信息                                  |
|      `rule`      |                                   分割线                                   |
|     `scope`      |                             显示作用域内的变量                             |
|    `segment`     |                        segment是Rich渲染的基本单元                         |
|    `spinner`     |                              加载显示动画效果                              |
|     `status`     |                                状态更新效果                                |
|     `syntax`     |                               显示 code 区域                               |
|     `table`      |                                    表格                                    |
|      `text`      |                                  本文效果                                  |
|     `theme`      |                                  默认风格                                  |
|   `traceback`    |                                    回溯                                    |
|      `tree`      |                                   树结构                                   |


## 自定义高亮


```py
from rich.theme import Theme
from rich.highlighter import RegexHighlighter
from rich.text import Text

console = Console(
    theme=Theme(
        {
            "variable": "dim",
        }
    )
)


class CommandHighlighter(RegexHighlighter):
    highlights = [
        r"(?P<variable>#{.*?})"
    ]

cmd_highlighter = CommandHighlighter()

line = "hello this is #{variable} test"
console.print(cmd_highlighter(Text.from_markup(line)))
```

