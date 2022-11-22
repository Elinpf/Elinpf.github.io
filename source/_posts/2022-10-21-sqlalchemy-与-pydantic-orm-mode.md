---
title: sqlalchemy 与 pydantic orm_mode
date: 2022-10-21 16:02:20
tags:
- python
- sqlalchemy
- sql
- todo
categories:
- 编程
- python
---

`pydantic`的`orm_mode`可以与`sqlalchemy` ORM联动

## 单一表的情况

```py
from sqlalchemy import Column, String, Integer
from sqlalchemy.ext.declarative import declarative_base
from pydantic import BaseModel, constr

Base = declarative_base()


class ParentORM(Base):
    __tablename__ = 'parent'

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    name = Column(String(30))
    age = Column(Integer)


class Parent(BaseModel):
    id: int
    name: constr(max_length=30)
    age: int

    class Config:
        orm_mode = True


if __name__ == '__main__':
    p_orm = ParentORM(id=1, name='John', age=30)
    p = Parent.from_orm(p_orm)
    print(p.name)
```

## 多个表关联

```py
from typing import List
from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from pydantic import BaseModel, constr

Base = declarative_base()


class ParentORM(Base):
    __tablename__ = 'parent'

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    name = Column(String(30))
    age = Column(Integer)

    children = relationship(
        "ChildORM", foreign_keys='ChildORM.parent_id', back_populates='parent'
    )


class ChildORM(Base):
    __tablename__ = 'child'

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    name = Column(String(30))
    age = Column(Integer)
    interests = Column(String(30))

    parent_id = Column(Integer, ForeignKey('parent.id'))

    parent = relationship(
        'ParentORM', foreign_keys='ChildORM.parent_id', back_populates='children'
    )


# 注意这个类的定义顺序, 因为后面要用到这个类，所以需要放在前面
class Children(BaseModel):
    id: int
    name: constr(max_length=30)
    age: int
    interests: constr(max_length=30)

    class Config:
        orm_mode = True


class Parent(BaseModel):
    id: int
    name: constr(max_length=30)
    age: int

    # 这里定义的是一个列表，pydantic 会自动把关联的类放在这里
    children: List[Children] = []

    class Config:
        orm_mode = True


if __name__ == '__main__':
    p_orm = ParentORM(id=1, name='John', age=30)
    c_orm = ChildORM(id=1, name='kk', age=10, interests='football')
    c_orm_2 = ChildORM(id=2, name='link', age=4, interests='basketball')

    c_orm.parent = p_orm
    c_orm_2.parent = p_orm

    p = Parent.from_orm(p_orm)

    print(len(p.children))
    print(p.children[0].name)
```