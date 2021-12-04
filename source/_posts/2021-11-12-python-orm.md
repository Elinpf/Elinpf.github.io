---
title: python SqlAlchemy ORM
date: 2021-11-12 09:51:06
tags:
- python
categories:
- 编程
- python
---

## 什么是ORM

ORM（Object Relationship Mapping）是一种将数据库表和对象的关系映射起来的方法。是完整软件的必要部分，将数据持久化。

映射关系如下图所示

![](1.png)

常用的ORM框架是SqlAlchemy，它提供了一个简单接口，无需使用SQL语句就可以完成对数据库的操作。


## 经典映射模式

使用经典映射模式，有一个好处就是将对象和表之间的映射关系解耦，将数据库的操作抽象出来，提高代码的可维护性。

```py model.py
class Device:
    def __init__(self, device_id: str):
        self.device_id: str = device_id
        self.hostname: str = ''
        self.version: str = ''
```

```py orm.py
from sqlalchemy.orm import mapper, relationship
from sqlalchemy import (
    Table,
    MetaData,
    Column,
    Integer,
    String
)

import model

metadata = MetaData()

devices = Table(
    'devices',
    metadata,
    Column('id', Integer, primary_key=True, autoincrement=True),
    Column('device_id', String(255), nullable=False),
    Column('hostname', String(255)),
    Column('version', String(255))
)

def start_mapper():
    mapper(model.Device, devices)
```

## 关系映射模式

使用方法参考[](!python-sqlalchemy-继承关系表)

## ORM事件

当ORM与类属性映射不能做到一一对应的情况下，重新获取类时没有覆盖到的属性不会被初始化，这种情况下，可以使用`load`事件在创建实例后立即对属性进行初始化。

```py orm.py
from sqlalchemy import event

@event.listens_for(Device, 'load')
def receive_load(target, _):
    target.uname = 'uname'
```


