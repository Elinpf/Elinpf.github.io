---
title: python pytest
date: 2021-10-13 09:22:11
tags:
- python
categories:
- 编程
- python
---

pytest 是强大的测试框架

当函数使用`test_`为开头的时候，就会在执行测试的时候进行测试。

执行命令为：

```
pytest -v -s test_file.py
```

## conftest.py

`conftest.py`的特点:

1. conftest.py与运行的用例要在同一个pakage下，并且有__init__.py文件
2. 不需要import导入 conftest.py，pytest用例会自动识别该文件，放到项目的根目录下就可以全局目录调用了，如果放到某个package下，那就在该package内有效，可有多个conftest.py
3. conftest.py配置脚本名称是固定的，不能改名称
4. conftest.py文件不能被其他文件导入
5. 所有同目录测试文件运行前都会执行conftest.py文件

在conftest.py中将会用到`@pytest.fixture`装饰器

## fixture

fixture函数如下：
```
fixture（scope='function'，params=None，autouse=False，ids=None，name=None）
```

- scope参数可以控制fixture的作用范围，scope：有四个级别参数"function"（默认），"class"，"module"，"session
- params：一个可选的参数列表，每个参数执行一遍，相当于for循环
- autouse：如果True，则为所有测试激活fixture func可以看到它。
- ids：每个字符串id的列表，每个字符串对应于params这样他们就是测试ID的一部分。如果没有提供ID它们将从params自动生成
- name：fixture的名称。

scope作用范围： session>module>class>function

- function：每一个函数或方法都会调用
- class：每一个类调用一次，一个类中可以有多个方法
- module：每一个.py文件调用一次，该文件内又有多个function和class
- session：是多个文件调用一次，可以跨.py文件调用，每个.py文件就是module


## pytest.ini

todo


## 测试代码覆盖率

`coverage` 用于对测试的时候，哪些代码被执行了，可以反映出完成程度。

`pip install pytest-cov`

使用

`pytest --cov --cov-report xml`

这样就会生成一个`xml`文件

命令行中使用`coverage report` 查看整体覆盖率

VsCode中推荐插件`Coverage Gutters`

配置:

![](1.png)
