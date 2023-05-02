---
title: python excel模块
date: 2021-10-25 16:14:50
tags:
- python
categories:
- 编程
- python
---

python 中使用execl推荐使用`openpyxl`模块

## 创建表和保存

### 创建新表

```py
wb = pyopenxl.Workbook() # 创建新Excel
sheet = wb.active  # 获取激活的表，也就是第一个
```

### 加载已有的Excel
```py
wb = pyopenxl.load_workbook(filename='path.xlsx')
sheet = wb['Sheet1'] # 获取表
```

### 修改表名

```py
sheet.title = 'new_sheet_name'
```

### 保存
```py
wb.save('path.xlsx')
```

## 迭代器

行迭代器

```py
for row in sheet.iter_rows(min_row=1, max_row=sheet.max_row, min_col=1, max_col=3):
    for cell in row:
        ...
```
