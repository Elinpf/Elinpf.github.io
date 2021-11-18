---
title: python sqlalchemy 使用Dict字段
date: 2021-11-18 14:59:02
tags:
- python
- sqlalchemy
categories:
- 编程
- python
---

SqlAlchemy对应的数据库的表结构，数据库是没有Dict字段的，所以只能通过`json`来存储。

而想要将其做成自动存储，需要使用`sqlalchemy.ext.mutable`模块。

```python
import json
from sqlalchemy.types import TypeDecorator, VARCHAR
from sqlalchemy.ext.mutable import Mutable


class JSONEncodedDict(TypeDecorator):
    "Represents an immutable structure as a json-encoded string."

    impl = VARCHAR

    def process_bind_param(self, value, dialect):
        if value is not None:
            value = json.dumps(value)
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            value = json.loads(value)
        return value


class MutableDict(Mutable, dict):
    @classmethod
    def coerce(cls, key, value):
        "Convert plain dictionaries to MutableDict."

        if not isinstance(value, MutableDict):
            if isinstance(value, dict):
                return MutableDict(value)

            # this call will raise ValueError
            return Mutable.coerce(key, value)
        else:
            return value

    def __setitem__(self, key, value):
        """捕获设置事件，并将自己设置为已修改"""

        dict.__setitem__(self, key, value)
        self.changed()

    def __delitem__(self, key):
        """捕获删除事件，并将自己设置为已修改"""

        dict.__delitem__(self, key)
        self.changed()

    def update(self, *args, **kwargs):
        """捕获update事件，并将自己设置为已修改"""

        dict.update(self, *args, **kwargs)
        self.changed()
```