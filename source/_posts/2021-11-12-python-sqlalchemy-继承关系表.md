---
title: python sqlalchemy 继承关系表
date: 2021-11-12 15:51:27
tags:
- python
- sqlalchemy
categories:
- 编程
- python
---

通常，我们会使用一个类来表示一个表，这个类的属性就是表中的字段，这个类的方法就是表中的操作。

但是继承关系的话，想把继承关系放到表中取表达就需要特殊的方法。

有两种方式，一种是对每个类都定义一个表，还有一种就是将所有类都放到一个表中。


## 对每个类都定义一个表

```python
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

Base = declarative_base()


class Item(Base):

    __tablename__ = 'item'
    id = Column(Integer, primary_key=True)
    name = Column(String(50))  # formerly known as type
    type = Column(String(50))

    __mapper_args__ = {
        'polymorphic_identity': 'item',
        'polymorphic_on': type,
    }


class Sword(Item):
    __tablename__ = 'sword'
    id = Column(Integer, ForeignKey('item.id'), primary_key=True)
    durability = Column(Integer, default=100)

    __mapper_args__ = {
        'polymorphic_identity': 'Sword',
    }


class Pistol(Item):
    __tablename__ = 'pistol'
    id = Column(Integer, ForeignKey('item.id'), primary_key=True)
    ammo = Column(Integer, default=10)

    __mapper_args__ = {
        'polymorphic_identity': 'Pistol',
    }


if __name__ == '__main__':

    engin = create_engine('sqlite:///:memory:', echo=False)
    session = sessionmaker(bind=engin)()
    Base.metadata.create_all(engin)

    sword = Sword(name='S1', durability=100)
    pistol = Pistol(name='P1', ammo=20)

    session.add(sword)
    session.add(pistol)
    session.commit()

    print(session.query(Item).all())
    print(session.execute('select * from item').fetchall())
    print(session.execute('select * from sword').fetchall())
    print(session.execute('select * from pistol').fetchall())

    print("====== Sword ======")
    s = session.query(Sword).first()  # type: Sword
    print("Sword.name: ", s.name)
    print("Sword.durability: ", s.durability)

    print("====== Pistol ======")
    p = session.query(Pistol).first()  # type: Pistol
    print("Pistol.name: ", p.name)
    print("Pistol.ammo: ", p.ammo)
```

output:

```text
[<__main__.Sword object at 0x000001BB35CD0940>, <__main__.Pistol object at 0x000001BB35D16BB0>]
[(1, 'S1', 'Sword'), (2, 'P1', 'Pistol')]
[(1, 100)]
[(2, 20)]
====== Sword ======
Sword.name:  S1
Sword.durability:  100
====== Pistol ======
Pistol.name:  P1
Pistol.ammo:  20
```

## 所有类都在一个表中

这样有一个弊端，就会导致所有子类都会共享其他之类特有属性

```python
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

Base = declarative_base()


class Item(Base):
    name = 'unnamed item'

    __tablename__ = 'item'
    id = Column(Integer, primary_key=True)
    type = Column(String(50))
    durability = Column(Integer, default=100)
    ammo = Column(Integer, default=10)

    __mapper_args__ = {
        'polymorphic_identity': 'item',
        'polymorphic_on': type
    }


class Sword(Item):
    name = 'Sword'

    __mapper_args__ = {
        'polymorphic_identity': 'sword',
    }


class Pistol(Item):
    name = 'Pistol'

    __mapper_args__ = {
        'polymorphic_identity': 'pistol',
    }


if __name__ == '__main__':
    engine = create_engine('sqlite:///:memory:', echo=False)
    session = sessionmaker(bind=engine)()
    Base.metadata.create_all(engine)

    sword = Sword(durability=20)
    pistol = Pistol(ammo=30)
    session.add(sword)
    session.add(pistol)
    session.commit()

    print(session.query(Item).all())
    print(session.execute('select * from item').fetchall())

    print("====== Sword ======")
    s = session.query(Sword).first()  # type: Sword
    print("Sword.name: ", s.name)
    print("Sword.durability: ", s.durability)

    print("====== Pistol ======")
    p = session.query(Pistol).first()  # type: Pistol
    print("Pistol.name: ", p.name)
    print("Pistol.ammo: ", p.ammo)
```

output:

```text
[<__main__.Sword object at 0x000002DB20A0D0A0>, <__main__.Pistol object at 0x000002DB20A4D580>]
[(1, 'sword', 20, 10), (2, 'pistol', 100, 30)]
====== Sword ======
Sword.name:  Sword
Sword.durability:  20
====== Pistol ======
Pistol.name:  Pistol
Pistol.ammo:  30
```

## 参考网站

- https://stackoverflow.com/questions/38519349/how-to-use-sqlalchemy-with-class-attributes-and-properties/38526500#38526500

- https://docs.sqlalchemy.org/en/14/orm/inheritance.html