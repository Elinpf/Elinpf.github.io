---
title: python -with- 代码块跳过
date: 2022-08-24 16:36:47
tags:
- python
categories:
- 编程
- python
---

- 参考[这篇文章](https://stackoverflow.com/questions/12594148/skipping-execution-of-with-block)

默认情况下，python中的with代码块是无法跳过的，定义如下：

```py
with EXPR as VAR:
    BLOCK
```

```py
mgr = (EXPR)
exit = type(mgr).__exit__  # Not calling it yet
value = type(mgr).__enter__(mgr)
exc = True
try:
    try:
        VAR = value  # Only if "as VAR" is present
        BLOCK
    except:
        # The exceptional case is handled here
        exc = False
        if not exit(mgr, *sys.exc_info()):
            raise
        # The exception is swallowed if exit() returns true
finally:
    # The normal and non-local-goto cases are handled here
    if exc:
        exit(mgr, None, None, None)
```

但是我们有时候又希望能过处理跳过的情况。该怎么做呢？

## with 的作用原理

想要使用with，必须返回结果（也就是VAR）这个变量的类必须包含`__enter__`和`__exit__`两个方法。

## 方法一：通过trace来跳过

原型为

```py
import sys

class SkipWithBlock(Exception):
    pass


class SkipContextManager:
    def __init__(self, skip):
        self.skip = skip

    def __enter__(self):
        if self.skip:
            sys.settrace(lambda *args, **keys: None)
            frame = sys._getframe(1)
            frame.f_trace = self.trace

    def trace(self, frame, event, arg):
        raise SkipWithBlock()

    def __exit__(self, type, value, traceback):
        if type is None:
            return  # No exception
        if issubclass(type, SkipWithBlock):
            return True  # Suppress special SkipWithBlock exception


with SkipContextManager(skip=True):    
    print('In the with block')  # Won't be called
print('Out of the with block')
```

### 替换 contextmanager 装饰器

对于上面的原型我们可以使用装饰器来替换：

替换 contextmanager 的方法为:

```py
import sys
from contextlib import _GeneratorContextManager
from functools import wraps


class SkipWithBlock(Exception):
    pass


class _ContextManager(_GeneratorContextManager):
    def __enter__(self):
        del self.args, self.kwds, self.func
        try:
            return next(self.gen)
        except StopIteration:
            sys.settrace(lambda *args, **keys: None)
            frame = sys._getframe(1)
            frame.f_trace = self.trace

    def trace(self, frame, event, arg):
        raise SkipWithBlock()

    def __exit__(self, type, value, traceback):
        if type is None:
            try:
                next(self.gen)
            except StopIteration:
                return False
            else:
                raise RuntimeError("generator didn't stop")
        elif issubclass(type, SkipWithBlock):
            return True
        else:
            if value is None:
                value = type()
            try:
                self.gen.throw(type, value, traceback)
            except StopIteration as exc:
                return exc is not value
            except RuntimeError as exc:
                if exc is value:
                    return False
                if type is StopIteration and exc.__cause__ is value:
                    return False
                raise
            except:
                if sys.exc_info()[1] is value:
                    return False
                raise
            raise RuntimeError("generator didn't stop after throw()")


def contextmanager(func):
    """这个contextmanager可以在没有yield的时候，主动跳过代码块"""
    @wraps(func)
    def helper(*args, **kwds):
        return _ContextManager(func, args, kwds)

    return helper
```

这么做会有个问题，就是无法在IDE中获取VAR的属性，不好用，而且无法做到一个函数同时包含直接调用和间接的with的能力。

### 利用特殊的类

上面的装饰器其实并不好用，另一种方法当需要跳过的时候，返回一个特殊类。

```py
def search_cmd(cmd=None) -> Cmd:
    if cmd:
        return Cmd 
    return NoneSkip()


class SkipWithBlock(Exception):
    pass


class Singleton(object):
    """单例类继承"""
    _instance = None

    def __new__(class_, *args, **kwargs):
        if not isinstance(class_._instance, class_):
            class_._instance = object.__new__(class_, *args, **kwargs)
        return class_._instance


class NoneSkip(Singleton):
    """
    简单模仿None类，但是可以用来作为-with-中的跳过
    使用bool()来判断是否为空
    """

    def __init__(self):
        self.none = None

    def __enter__(self):
        if sys.gettrace():
            return self

        # NOTE 存在一定的问题，当程序处于调试状态的时候，调试进程会被破坏：
        # https://pydev.blogspot.com/2007/06/why-cant-pydev-debugger-work-with.html
        sys.settrace(lambda *args, **keys: None)
        frame = sys._getframe(1)
        frame.f_trace = self.trace

    def trace(self, frame, event, arg):
        raise SkipWithBlock()

    def __bool__(self):
        return False

    def __exit__(self, type, value, traceback):
        if type is None:
            return  # No exception
        if issubclass(type, SkipWithBlock):
            return True  # Suppress special SkipWithBlock exception

    def __eq__(self, other):
        return self.none == other

    def __ne__(self, other):
        return self.none != other

    def __getattr__(self, __name: str):
        # NOTE 当调用不存在的属性时，就是触发这个，跳过-with-后面的内容
        raise SkipWithBlock()
```

这里其实使用了两种跳过方式：
1. `frame.f_trace = self.trace` 这种方式是直接跳过，不会调用函数的内部代码
2. `__getattr__`中raise SkipWithBlock() 这种方式是调用函数的内部代码，但是一旦遇到执行了VAR的方法后面的内容就会被跳过。

那么为什么要做两个呢？
因为如果使用第一种方式，那么就会导致调试器无法跟踪到函数的内部代码，这样就会导致调试器无法跟踪到程序后面的代码。
而第二种方法，可以跟踪到函数的内部代码，但是会执行前面一部分的代码。

所以会有一个判断，当不处于调试状态的时候，使用第一种方式。
当处于调试状态的时候，使用第二种方式。

