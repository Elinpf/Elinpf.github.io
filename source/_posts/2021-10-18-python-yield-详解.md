---
title: python yield 详解
date: 2021-10-18 10:04:40
tags:
- python
categories:
- 编程
- python
---

要理解`yield`，首先要清楚在有yield的函数，在执行的时候，其实返回的一个生成器对象。然后通过`next()`执行到yield语句停下，并返回yield所跟的值，然后一直等待`next()`的执行

## 简单的例子

```py
def foo():
    print("starting...")
    while True:
        res = yield 4
        print("res:",res)
g = foo()
print(next(g))
print("*"*20)
print(next(g))
```

输出：

```
starting...
4
********************
res: None
4
```

流程是：
1. `g = foo()`得到的是生成器对象，还并没有执行。
2. `next((g))`执行g生成器知道yield语句，并返回4。
3. 打印`*`
4. `next(g)`继续执行，但是没有`send()`给出值，所有res为None

如果想要让res获得值，那么将第二个`next(g)`换成`next(g,5)`，这样res就可以获得值5。或者`g.send(5)`也是一样。

## for循环

如果一次次的调用`next()`未免也太过麻烦了，大多数情况可以使用`for()`来遍历生成器。也样也可避免使用`StopIteration`异常来停止遍历。


## with语句

使用上下文管理器

```py
from contextlib import contextmanager

class Query(object):

    def __init__(self, name):
        self.name = name

    def query(self):
        print('Query info about %s...' % self.name)
    

@contextmanager
def create_query(name):
    print('Begin')
    q = Query(name)
    yield q
    print('End')


with create_query('Bob') as q:
    q.query()
```

输出：

```
Begin
Query info about Bob...
End
```

## yield from

看个例子

```py
def g1():     
     yield range(5)
def g2():
     yield from range(5)

it1 = g1()
it2 = g2()
for x in it1:
    print(x)

for x in it2:
    print(x)
```

输出:

```
range(0, 5)
0
1
2
3
4
```

可以知道yield返回的是可迭代对象，而`yield from`返回的是迭代器执行后每个item。

**所以`yield from iterable`的本质就是`for item in iterable: yield item`**

## 取返回值

正常情况下，迭代器是无法获取到返回值的，但是可以通过两种方式获取
1. 使用`StopIteration`异常
2. 使用类，然后取类的变量

### 使用`StopIteration`

```py
def fib(max):
  n, a, b = 0, 0, 1
  while n < max:
    yield b
    a, b = b, a + b
    n = n + 1
  return 'done'
# 捕获Generator的返回值
g = fib(6)
while True:
  try:
    x=next(g)
    print('g=',x)
  except StopIteration as e:
    print('Generrator return value:', e.value)
    break
```
