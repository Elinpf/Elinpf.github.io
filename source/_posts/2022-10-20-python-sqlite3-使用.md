---
title: python sqlite3 使用
date: 2022-10-20 09:37:34
tags:
- python
- sql
categories:
- 编程
- python
---

python3 中自带`sqlite3`数据库，无需安装。所以学习和使用`sqlite3`都是非常值得的。

`sqlite`中的一个重要概念就是游标，可以理解为windows中的文件句柄，或者就是数组中的指针。

```py
import sqlite3

# 连接数据库，如果数据库不存在，则创建
con = sqlite3.connect('test.db')

# 创建游标
cur = con.cursor()

# 创建表
cur.execute(
    "CREATE TABLE IF NOT EXISTS test(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER)"
)

# ----- 增 -----

# 插入数据
cur.execute("INSERT INTO test(name, age) VALUES(?, ?)", ("elin", 30))

# or 插入多条数据
cur.executemany("INSERT INTO TEST(name, age) VALUES(?, ?)", [('lili', 27), ('wulu', 3)])


# ----- 删 -----
cur.execute("DELETE FROM test WHERE name = ?", ("wulu",))


# ----- 改 -----
cur.execute("UPDATE test SET age = ? WHERE name = ?", (28, "lili"))


# ----- 查 -----
# 查询数据
res = cur.execute("SELECT * FROM test")

# 轮询
for row in res.fetchall():
    print(row)

# 提交
con.commit()

# 回滚, 如果出现错误，可以回滚到上一次提交的状态
con.rollback()

# 删除表
cur.execute("DROP TABLE test")

# 关闭游标
cur.close()
# 关闭数据库
con.close()
```
