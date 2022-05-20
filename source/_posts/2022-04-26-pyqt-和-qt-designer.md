---
title: PyQt 和 Qt Designer
date: 2022-04-26 11:09:44
tags:
- python
categories:
- 编程
- python
---

- `PyQt`是 Python 语言的 GUI 编程解决方案之一。
- `Qt Designer`是PyQt程序UI界面的实现工具，使用Qt Designer可以拖拽、点击完成GUI界面设计，并且设计完成的.ui程序可以转换成.py文件供python程序调用


## Qt Desinger

推荐阅读[这篇文章](https://blog.l0v0.com/posts/bea01990.html)

另外在使用VsCode的时候，推荐`Qt for python`插件。将一下两个选项改为`-o "${fileDirname}${pathSeparator}${fileBasenameNoExtension}.py"`

![](1.png)

这样的话，就可以在每次保存Qt Desinger的时候，自动编译更新`.ui`文件为`.py`了。

## PyQt

在完成了UI设计后一般通过以下方式执行。

```py
from PyQt5 import QtWidgets
from .ui import Ui_Form


class PyTemplateWindow(QtWidgets.QWidget, Ui_Form):
    def __init__(self):
        super(PyTemplateWindow, self).__init__()
        self.setupUi(self)

 if __name__ == '__main__':
    app = QtWidgets.QApplication(sys.argv)
    win = PyTemplateWindow()
    win.show()
    sys.exit(app.exec_())
```

## 打包

打包方式使用`pyinstaller`

`pyinstaller -F -w window.py`

这样可以打包为单个文件，如果需要对打包的参数进行调整，可以在刚刚生成的`.spec`文件中做修改。修改完成后
`pyinstaller <.spec>`