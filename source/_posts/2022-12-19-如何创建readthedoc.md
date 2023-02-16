---
title: 如何创建readthedoc
date: 2022-12-19 10:05:13
tags:
- python
categories:
- 编程
- python
---

[readthedocs官方教程文档](https://docs.readthedocs.io/en/stable/tutorial/index.html)
[sphinx中文文档](https://www.sphinx-doc.org/zh_CN/master/usage/index.html)
[reStructuredText 教程](https://rst-tutorial-elinpf.readthedocs.io/en/latest/)


## 在项目中创建

一般使用的是shpinx, 在项目根目录中创建`docs`文件夹

```
cd docs
sphinx-quickstart
```

**推荐还是将 `build` 和 `source` 分开**

## 主题

推荐使用`sphinx_rtd_theme`主题，首先需要安装

```
pip install sphinx-rtd-theme
```

然后在`conf.py`中使用

```py conf.py
import sphinx_rtd_theme

html_theme = 'sphinx_rtd_theme'
```

## autodoc

[中文文档](https://www.sphinx-doc.org/zh_CN/master/usage/extensions/autodoc.html)

1. 在`docs/requirements.txt` 文件中定义需要的python包

```txt docs/requirements.txt
alabaster==0.7.12
Sphinx==5.3.0
sphinx-rtd-theme==1.1.1
sphinx-copybutton==0.5.0
```

2. 在`conf.py`中引入，然后进行扩展定义

```py conf.py
import os
import sys
sys.path.insert(0, os.path.abspath('..'))

extensions = [
    'sphinx.ext.autodoc',
    "sphinx.ext.viewcode",
    "sphinx.ext.napoleon",
    "sphinx.ext.intersphinx",
    "sphinx.ext.autosectionlabel",
    'sphinx_copybutton',
]
```

```rst
.. autoclass:: net_inspect.NetInspect
   :members: 
   :undoc-members:
```

如果构建不成功，去[readthedocs](https://readthedocs.org/) 构建里面查看原因，有可能是因为有些模块没有引入，
这时候就需要在`docs/requirements.txt`中加入这个模块即可。

[构建不成功参考问答](https://stackoverflow.com/questions/10324393/sphinx-build-fail-autodoc-cant-import-find-module)

## 定义开始文件为 index

```py conf.py
master = 'index'
```

## 本地创建 html

```bash
./make.bat clean ; ./make.bat html
```

## 发布

[readthedocs](https://readthedocs.org/dashboard/) 中导入项目即可，成功后每次github上面有更新，readthedocs会自动更新