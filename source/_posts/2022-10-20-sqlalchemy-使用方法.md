---
title: sqlalchemy 使用方法
date: 2022-10-20 11:11:35
tags:
- python
- sqlalchemy
- sql
categories:
- 编程
- python
---

`SQLAlchemy` 是 python 的一个数据库 ORM 工具，提供了强大的对象模型间的转换，可以满足绝大多数数据库操作的需求，并且支持多种数据库引擎 (sqlite，mysql，postgres, mongodb 等)

`SQLAlchemy`连接数据库的字符串：

```
mysql://username:password@hostname/database 
postgresql://username:password@hostname/database 
sqlite:////absolute/path/to/database 
sqlite:///c:/absolute/path/to/database
sqlite:///:memory:
```

## 使用传统方式connect连接数据库使用

```py
from sqlalchemy import create_engine

DB_CONNECT_STRING = 'sqlite:///:memory:'

# 创建数据库引擎,echo为True,会打印所有的sql语句
engine = create_engine(DB_CONNECT_STRING, echo=True)

# 创建一个connection，这里的使用方式与python自带的sqlite的使用方式类似
# 使用 memory 可以不用 commit， 使用文件就需要commit
with engine.connect() as con:
    trans = con.begin()
    try:
        con.execute(
            "CREATE TABLE IF NOT EXISTS test(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER)"
        )
        con.execute("INSERT INTO test (name, age) VALUES (?, ?)", ('elin', 30))
        trans.commit()
    except:
        trans.rollback()
        raise
```

## 使用 session 方式

connection 是一般使用数据库的方式，sqlalchemy 还提供了另一种操作数据库的方式，通过 session 对象，session 可以记录和跟踪数据的改变，在适当的时候提交，并且支持强大的 ORM 的功能，下面是基本使用。

```py
import os
from sqlalchemy import create_engine 
from sqlalchemy.orm import sessionmaker 
 
# 数据库连接字符串 
root_path = os.path.dirname(__file__).replace('\\', '/')
DB_CONNECT_STRING = f'sqlite:///{root_path}/sqlit.db' 
 
# 创建数据库引擎,echo为True,会打印所有的sql语句 
engine = create_engine(DB_CONNECT_STRING, echo=True) 
 
# 创建会话类 
DB_Session = sessionmaker(bind=engine) 
 
# 创建会话对象 
session = DB_Session() 
 
# dosomething with session 
 
# 用完记得关闭，也可以用with 
session.close()
```

上面创建了session对象，也可以直接操作数据库

```
session.execute('select * from User') 
session.execute("insert into User(name, age) values('bomo', 13)") 
session.execute("insert into User(name, age) values(:name, :age)", {'name': 'bomo', 'age':12}) 
 
# 如果是增删改，需要commit 
session.commit()
```

### ORM

ORM 框架就是将对象和数据库映射起来，实现了解耦。

#### 无关联数据表


```py models/__init__.py
from sqlalchemy.ext.declarative import declarative_base

# 声明一个Base基类
Base = declarative_base()
```

```py models/user.py
from sqlalchemy import Column, Integer, String
from . import Base


class User(Base):
    __tablename__ = 'User'

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50))
    age = Column(Integer)
```

```py models/role.py
from sqlalchemy import Column, Integer, String
from . import Base


class Role(Base):
    __tablename__ = 'Role'

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50))
```

Column 可以定义的相关参数：

- name：名称 (可以不写)
- type：列类型
- autoincrement：自增
- default：默认值
- index：索引
- nullable：可空
- primary_key：外键


```py learn_sqlalchemy.py
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Base
from models.user import User
from models.role import Role


root_path = os.path.dirname(__file__).replace('\\', '/')
DB_CONNECT_STRING = f'sqlite:///{root_path}/sqlalchemy.db'

# 创建数据库引擎, echo = True 会打印出所有的SQL语句
engine = create_engine(DB_CONNECT_STRING, echo=False)

# 创建会话类
DB_Session = sessionmaker(bind=engine)

# 创建会话对象
session = DB_Session()

# 1. 创建表(如果表已经存在，不会重复创建)
Base.metadata.create_all(engine)


# 2. 插入数据
u = User(name='user1', age=10)
r = Role(name='user')

# 2.1 使用 add 添加到 session， 如果已经存在，不会重复添加
session.add(u)
session.add(r)
session.commit()
print(u.id)

# 3. 修改数据

# 3.1 使用merge方法，如果存在则修改，不存在则添加
r.name = 'admin'
session.merge(r)

# 3.2 也可以用这种方式修改
session.query(Role).filter(Role.id == 1).update({'name': 'admin'})

# 4. 删除数据
session.query(Role).filter(Role.id == 1).delete()

# 5. 查询数据
# 5.1 返回结果集的第二项
user = session.query(Role).get(2)

# 5.2 返回结果集的第2-3项
users = session.query(Role)[1:3]

# 5.3 条件查询
user = session.query(User).filter(User.id < 6).first()

# 5.4 排序
users = session.query(User).order_by(User.name)

# 5.5 降序（需要导入desc方法）
from sqlalchemy import desc

users = session.query(User).order_by(desc(User.name))

# 5.6 只查询部分属性
users = session.query(User.name).order_by(desc(User.name))
for user in users:
    print(user.name)

# 5.7 给结果集的列取别名
users = session.query(User.name.label('user_name')).all()
for user in users:
    print(user.user_name)

# 5.8 去重查询(需要导入distinct方法)
from sqlalchemy import distinct

users = session.query(distinct(User.name).label('name')).all()
for user in users:
    print(user.name)

# 5.9 统计查询(需要导入func)
from sqlalchemy import func

user_count = session.query(User.name).order_by(User.name).count()
age_avg = session.query(func.avg(User.age)).first()
age_sum = session.query(func.sum(User.age)).first()

# 5.10 分组查询
users = session.query(func.count(User.name).label('count'), User.age).group_by(User.age)
for user in users:
    print(f'ags: {user.age}, count: {user.count}')

session.commit()

session.close()
```

#### 多表关联

现在我们将`Role`关联到`User`上，使每个User都可以拥有两个Role身份。

所以要在父表上创建外键，然后使用`relationship`进行关联

```py models/user.py
from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from . import Base


class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50))
    age = Column(Integer)

    # 添加角色id外键（关联到Role表的id属性）, 这里使用的表名和列名
    # 这个值只会在写入到数据库的时候自动添加
    role_id = Column(Integer, ForeignKey('roles.id'))
    # 添加第二角色外键
    second_role_id = Column(Integer, ForeignKey('roles.id'))

    # 添加关联属性，关联到role_id上, 这里使用的是类名和属性名
    role = relationship(
        'Role',
        foreign_keys='User.role_id', # 都指到父表的外键上
        back_populates='users',  # 指到关联表对应的relationship属性上
    )
    # 添加关联属性，关联到second_role_id上
    second_role = relationship(
        'Role',
        foreign_keys='User.second_role_id',
        back_populates='second_users',
    )
```

```py models/role.py
from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship

from . import Base


class Role(Base):
    __tablename__ = 'roles'

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50))

    # 添加与User.role_id的关联
    users = relationship(
        'User',
        foreign_keys='User.role_id', # 都指到父表的外键上
        back_populates='role',
    )

    # 添加与User.second_id的关联
    second_users = relationship(
        'User',
        foreign_keys='User.second_role_id',
        back_populates='second_role',
    )
```

relationship中的参数:

**back_populates 参数**
relationship 函数是 sqlalchemy对关系之间提供的一种便利的调用方式, back_populates 参数则对关系提供反向引用的声明。
在最新版本的sqlalchemy中对relationship引进了back_populates参数， 两个参数的效果完全一致。

backref 和 back_populates 两个参数的区别

- backref 只需要在 Parent 类中声明 children，Child.parent 会被动态创建。
- back_populates 必须在两个类中显式地使用 back_populates，更显繁琐，理解更直观

**uselist**
如果是一对一的话，可以加上`uselist=False`, 那么返回的就是单个，而不是数组了

```py learn_sqlalchemy_relationship.py
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Base
from models.user import User
from models.role import Role

root_path = os.path.dirname(__file__).replace('\\', '/')
DB_CONNECT_STRING = f'sqlite:///{root_path}/sqlalchemy_relationship.db'

engine = create_engine(DB_CONNECT_STRING, echo=True)
DB_Session = sessionmaker(bind=engine)
session = DB_Session()

Base.metadata.create_all(engine)

u = User(name='dog', age=30)
r = Role(name='admin')
r2 = Role(name='user')

u.role = r
u.second_role = r2
session.add(u)
session.commit()

# 联合查询
users = session.query(User).join(Role, Role.id == User.role_id)
for u in users:
    print(u.name)

# 多表查询
users = session.query(User, Role).filter(User.role_id == Role.id)
for u, r in users:
    print(u.name)

session.close()
```