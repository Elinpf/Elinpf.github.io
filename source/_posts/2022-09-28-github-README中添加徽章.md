---
title: github README中添加徽章
date: 2022-09-28 17:16:19
tags:
- python
categories:
- 编程
- python
---

![](1.png)

`README.md`中添加徽章的方法

## 静态标签

大部分标签可以再[shields.io](https://shields.io/)中找到并直接使用

## 代码测试覆盖率标签

使用[codecov](https://app.codecov.io/)

注册授权后，选择仓库，将`TOKEN`复制到`Github`的`Secrets`中。

```yaml
name: Coverage upload to Codecov

on:
  push:
    branches:
      - master

jobs:
  coverage:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.x"
      - name: Install Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install poetry
          poetry install
      - name: Run Pytest Coverage
        run: |
          poetry run python -m pytest --cov --cov-report xml
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v2
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          file: ./coverage.xml
          flags: unittests
```

pull后等待action 上传 `coverage.xml`文件到`codecov`。

然后到`codecov`的`settings/badge`中选择`markdown`，复制到`README.md`中。