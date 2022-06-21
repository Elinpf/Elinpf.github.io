---
title: python tox 任务自动化工具使用方法
date: 2022-06-21 15:39:39
tags:
- python
categories:
- 编程
- python
---

[tox](https://tox.wiki/en/latest/) 是对任务进行自动化的工具。

平常测试的时候，如果只是单一的测试，比如只有pytest，这样还好。
但是如果涉及到多python版本，多个测试内容，比如涉及 black、 flake8、 yamllint 这些，那么一次次的测试就会很麻烦了。

这时就要用到tox

tox依赖于项目文件夹中的`tox.ini`配置文件运行, [tox config](https://tox.wiki/en/latest/config.html)

## 基础例子

```ini
[tox]
isolated_build = True
envlist = py38,black,flake8,yamllint
skip_missing_interpreters = true
download = true

[testenv]
passenv = TRAVIS TRAVIS_*
whitelist_externals = poetry
deps = poetry
commands =
    poetry install 
    python -m pytest {posargs}

[testenv:black]
deps = black
commands = black ./ --diff --check

[testenv:flake8]
deps = flake8
commands = flake8 ./

[testenv:yamllint]
deps = yamllint
commands = yamllint ./

[flake8]
# Line length managed by black
ignore = E501
exclude = .git,.tox,.venv,venv
```

Action:

```yml
name: Check Templates

on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
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
```




## 高级例子

```ini
[tox]
envlist =
    fix_lint
    py310
    py39
    py38
    py37
    py36
    py35
    py27
    pypy3
    pypy
    coverage
    docs
    readme
isolated_build = true
skip_missing_interpreters = true
minversion = 3.12

[testenv]
description = run the tests with pytest under {basepython}
passenv =
    CURL_CA_BUNDLE
    PIP_CACHE_DIR
    PYTEST_*
    REQUESTS_CA_BUNDLE
    SSL_CERT_FILE
setenv =
    COVERAGE_FILE = {env:COVERAGE_FILE:{toxworkdir}/.coverage.{envname}}
    PIP_DISABLE_PIP_VERSION_CHECK = 1
    {py27,pypy}: PYTHONWARNINGS = ignore:DEPRECATION::pip._internal.cli.base_command
extras =
    testing
commands =
    pytest \
      --cov "{envsitepackagesdir}/tox" \
      --cov-config "{toxinidir}/tox.ini" \
      --junitxml {toxworkdir}/junit.{envname}.xml \
      {posargs:.}

[testenv:fix_lint]
description = format the code base to adhere to our styles, and complain about what we cannot do automatically
passenv =
    {[testenv]passenv}
    PRE_COMMIT_HOME
    PROGRAMDATA
basepython = python3.10
skip_install = true
deps =
    pre-commit>=2.16
extras =
    lint
commands =
    pre-commit run --all-files --show-diff-on-failure {posargs}
    python -c 'import pathlib; print("hint: run \{\} install to add checks as pre-commit hook".format(pathlib.Path(r"{envdir}") / "bin" / "pre-commit"))'

[testenv:coverage]
description = [run locally after tests]: combine coverage data and create report;
    generates a diff coverage against origin/master (can be changed by setting DIFF_AGAINST env var)
passenv =
    {[testenv]passenv}
    DIFF_AGAINST
setenv =
    COVERAGE_FILE = {toxworkdir}/.coverage
skip_install = true
deps =
    coverage>=6.2
    diff-cover>=6.4
parallel_show_output = true
commands =
    coverage combine
    coverage report -m
    coverage xml -o {toxworkdir}/coverage.xml
    coverage html -d {toxworkdir}/htmlcov
    diff-cover --compare-branch {env:DIFF_AGAINST:origin/master} {toxworkdir}/coverage.xml
depends = py27, py35, py36, py37, py38, py39, py310, pypy, pypy3

[testenv:docs]
description = invoke sphinx-build to build the HTML docs
basepython = python3.10
extras =
    docs
commands =
    sphinx-build -d "{toxworkdir}/docs_doctree" docs "{toxworkdir}/docs_out" --color -W --keep-going -n -bhtml {posargs}
    python -c 'import pathlib; print("documentation available under file://\{0\}".format(pathlib.Path(r"{toxworkdir}") / "docs_out" / "index.html"))'

[testenv:readme]
description = check that the long description is valid
basepython = python3.9
skip_install = true
deps =
    twine>=3.7.1
extras =
commands =
    pip wheel -w {envtmpdir}/build --no-deps .
    twine check {envtmpdir}/build/*

[testenv:exit_code]
description = commands with several exit codes
basepython = python3.10
skip_install = true
commands =
    python3.10 -c "import sys; sys.exit(139)"

[testenv:X]
description = print the positional arguments passed in with echo
commands =
    echo {posargs}

[testenv:release]
description = do a release, required posarg of the version number
passenv =
    *
basepython = python3.10
deps =
    gitpython>=3.1.24
    packaging>=21.3
    towncrier>=21.3
commands =
    python {toxinidir}/tasks/release.py --version {posargs}

[testenv:dev]
description = dev environment with all deps at {envdir}
usedevelop = true
deps =
    {[testenv:release]deps}
extras =
    docs
    testing
commands =
    python -m pip list --format=columns
    python -c "print(r'{envpython}')"

[flake8]
max-complexity = 22
max-line-length = 99
ignore = E203, W503, C901, E402, B011

[pep8]
max-line-length = 99

[coverage:run]
branch = true
parallel = true

[coverage:report]
skip_covered = True
show_missing = True
exclude_lines =
    \#\s*pragma: no cover
    ^\s*raise AssertionError\b
    ^\s*raise NotImplementedError\b
    ^\s*return NotImplemented\b
    ^\s*raise$
    ^if __name__ == ['"]__main__['"]:$

[coverage:paths]
source = src/tox
    */.tox/*/lib/python*/site-packages/tox
    */.tox/pypy*/site-packages/tox
    */.tox\*\Lib\site-packages\tox
    */src/tox
    *\src\tox

[pytest]
addopts = -ra --showlocals --no-success-flaky-report
testpaths = tests
xfail_strict = True
markers =
    git
    network

[isort]
profile = black
line_length = 99
known_first_party = tox,tests
```

Action:

```yml
name: check
on:
  push:
    branches: [master, 'test-me-*']
    tags:
  pull_request:
  schedule:
    - cron: "0 8 * * *"

concurrency:
  group: check-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    name: test ${{ matrix.py }} - ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        py:
          - "3.10"
          - "pypy-3.7-v7.3.7"  # ahead to start it earlier because takes longer
          - "pypy-2.7-v7.3.6"  # ahead to start it earlier because takes longer
          - "3.9"
          - "3.8"
          - "3.7"
          - "3.6"
          - "3.5"
          - "2.7"
        os:
          - ubuntu-20.04
          - windows-2022
          - macos-10.15

    steps:
      - name: Setup python for tox
        uses: actions/setup-python@v2
        with:
          python-version: "3.10"
      - name: Install tox
        run: python -m pip install tox
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0
      - name: Setup python for test ${{ matrix.py }}
        uses: actions/setup-python@v2
        with:
          python-version: ${{ matrix.py }}
      - name: Pick environment to run
        run: |
          import codecs
          import os
          import platform
          import sys
          cpy = platform.python_implementation() == "CPython"
          base =("{}{}{}" if cpy else "{}{}").format("py" if cpy else "pypy", *sys.version_info[0:2])
          env = "TOXENV={}\n".format(base)
          print("Picked:\n{}for{}".format(env, sys.version))
          with codecs.open(os.environ["GITHUB_ENV"], "a", "utf-8") as file_handler:
               file_handler.write(env)
        shell: python
      - name: Setup test suite
        run: tox -vv --notest
      - name: Run test suite
        run: tox --skip-pkg-install
        env:
          PYTEST_ADDOPTS: "-vv --durations=20"
          CI_RUN: "yes"
          DIFF_AGAINST: HEAD
      - name: Rename coverage report file
        run: import os; import sys; os.rename(".tox/.coverage.{}".format(os.environ['TOXENV']), ".tox/.coverage.{}-{}.format(os.environ['TOXENV'], sys.platform)")
        shell: python
      - name: Upload coverage data
        uses: actions/upload-artifact@v2
        with:
          name: coverage-data
          path: ".tox/.coverage.*"

  coverage:
    name: Combine coverage
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0
      - uses: actions/setup-python@v2
        with:
          python-version: "3.10"
      - name: Install tox
        run: python -m pip install tox
      - name: Setup coverage tool
        run: tox -e coverage --notest
      - name: Install package builder
        run: python -m pip install build
      - name: Build package
        run: pyproject-build --wheel .
      - name: Download coverage data
        uses: actions/download-artifact@v2
        with:
          name: coverage-data
          path: .tox
      - name: Combine and report coverage
        run: tox -e coverage
      - name: Upload HTML report
        uses: actions/upload-artifact@v2
        with:
          name: html-report
          path: .tox/htmlcov

  check:
    name: ${{ matrix.tox_env }} - ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os:
          - ubuntu-20.04
          - windows-2022
        tox_env:
          - dev
          - docs
          - readme
        exclude:
          - { os: windows-2022, tox_env: readme }
    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0
      - name: Setup Python "3.10"
        uses: actions/setup-python@v2
        with:
          python-version: "3.10"
      - name: Install tox
        run: python -m pip install tox
      - name: Setup test suite
        run: tox -vv --notest -e ${{ matrix.tox_env }}
      - name: Run test suite
        run: tox --skip-pkg-install -e ${{ matrix.tox_env }}

  publish:
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags')
    needs: [ check, coverage ]
    runs-on: ubuntu-20.04
    steps:
      - name: Setup python to build package
        uses: actions/setup-python@v2
        with:
          python-version: "3.10"
      - name: Install build
        run: python -m pip install build
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0
      - name: Build sdist and wheel
        run: python -m build -s -w . -o dist
      - name: Publish to PyPi
        uses: pypa/gh-action-pypi-publish@master
        with:
          skip_existing: true
          user: __token__
          password: ${{ secrets.pypi_password }}
```