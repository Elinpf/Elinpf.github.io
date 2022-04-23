---
title: python dataclass 与 namedtuple
date: 2022-03-10 09:55:06
tags:
- python
categories:
- 编程
- python
---

`dataclass` 与 `namedtuple`都是python重要的数据结构

## 为什么要用到这两个数据结构

1. 如果只是简单的返回`return ('name', 30)` 这样的话，就无法确保返回值被准确的调用
2. 如果使用`return {'name': 'Elin', 'age': 30}` 这样的话无法使用散列，并且需要跟踪key名称。另外dict是可变的。

## `dataclass` 和 `namedtuple` 的差别

同样使数据结构，但是两个有一些差别。

`dataclass`:
- 可以设置默认值
- 定义`__post_init__`方法来延迟初始化一些默认值
- 默认不支持hash，需要关闭`unsafe_hash`参数
- 生成后可以修改值

```py
from dataclasses import dataclass


@dataclass
class Person:
    name: str
    age: int
    title: str = None

    def __post_init__(self):
        self.title = f"Hello {self.name}"

    def welcome(self):
        return f"Welcome {self.name}"


p1 = Person("John", 30)
print(p1.title)
# Hello John
print(p1.welcome())
# Welcome John

```


`namedtuple`:

- 不能设置默认值
- 生成后不能修改值
- 使用`typing.NamedTuple`自定义类

```py
from collections import namedtuple

Person = namedtuple('PersonA', 'name age')

p1 = Person(name='John', age=30)
print(p1.name)
```

```py
from typing import NamedTuple


class Person(NamedTuple):
    name: str
    age: int

    def welcome(self):
        return f"welcome {self.name}"


p1 = Person(name='John', age=30)
print(p1.welcome())
```