---
title: github python自动Build后发布到PyPI
date: 2022-04-24 15:28:29
tags:
- python
categories:
---

```yml .github/workflows/release.yml
name: Upload Python Package

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    - name: Setup Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.x'
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install setuptools wheel
    - name: Build
      run: |
        python setup.py sdist bdist_wheel
    - name: Publish distribution 📦 to PyPI
      uses: pypa/gh-action-pypi-publish@master
      with:
        password: ${{ secrets.PYPI_PASSWORD }}
```

首先要在[PyPi](https://pypi.org/manage/account/#api-tokens)中申请token，然后再到github中的仓库里面
`Setting -> Secret`中添加Token，名称就为`PYPI_PASSWORD`

```yml
on:
  push:
    tags:
      - 'v*'
```

这个的意思是当push打标签的时候开头为`v`。将会执行这个Action。

## 使用 poetry 构建

```yml .github/workflows/release.yml
name: Upload Python Package

on:
  push:
    tags:
      - 'v*'

jobs:
  publish:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    - name: Setup Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.x'
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install poetry
    - name: Build and Publish distribution 📦to PyPI
      run: |
        poetry config pypi-token.pypi ${{ secrets.PYPI_PASSWORD }}
        poetry publish --build
```

## 先测试，测试成功后发布

我们还可以先做测试，测试成功后再发布。

```yml .github/workflows/release.yml
name: Check Templates and Publish

on:
  push:
    branches: [master, dev, test-me-*]
    tags: [v*]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
      with:
        fetch-depth: 0
    - name: Setup Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.8'
    - name: Install Dependencies
      run: |
        python -m pip install --upgrade pip
        pip install poetry
        poetry install
    - name: Run Scripts
      run: |
        poetry run tox

  publish:
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags')
    needs: check
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
      with:
        fetch-depth: 0
    - name: Setup Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.x'
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install poetry
    - name: Build and Publish distribution 📦to PyPI
      run: |
        poetry config pypi-token.pypi ${{ secrets.PYPI_PASSWORD }}
        poetry publish --build
```

`on: [push, pull_request]`的意思是当push或者pull_request的时候执行这个Action。