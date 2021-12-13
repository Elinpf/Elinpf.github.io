---
title: python 打包分发(setup.py)的编写
date: 2021-12-03 14:42:42
tags:
- python
categories:
- 编程
- python
---

## python 包格式

Python的包分为源码包和二进制包，源码包就是将源码打包成一个压缩文件。而二进制包分为`.egg`和`.whl`。

`whl`现在被认为是Python的标准二进制格式。

## setup.py 文件

`setup.py`文件使用`setuptools`中的`setup()`函数来定义包的各种属性。 

### setup()函数的参数

常见函数如下：

|         参数         |                           说明                           |
| :------------------: | :------------------------------------------------------: |
|         name         |                          包名称                          |
|       version        |                          包版本                          |
|        author        |                        程序的作者                        |
|     author_email     |                   程序的作者的邮箱地址                   |
|      maintainer      |                          维护者                          |
|   maintainer_email   |                     维护者的邮箱地址                     |
|         url          |                      程序的官网地址                      |
|       license        |                      程序的授权信息                      |
|     description      |                      程序的简单描述                      |
|   long_description   |                      程序的详细描述                      |
|      platforms       |                  程序适用的软件平台列表                  |
|     classifiers      |                    程序的所属分类列表                    |
|       keywords       |                     程序的关键字列表                     |
|       packages       |   需要处理的包目录(通常为包含 `__init__.py` 的文件夹)    |
|      py_modules      |               需要打包的 Python 单文件列表               |
|     download_url     |                      程序的下载地址                      |
|       cmdclass       |                      添加自定义命令                      |
|     package_data     |                指定包内需要包含的数据文件                |
| include_package_data |    自动包含包内所有受版本控制(cvs/svn/git)的数据文件     |
| exclude_package_data | 当 include_package_data 为 True 时该选项用于排除部分文件 |
|      data_files      |       打包时需要打包的数据文件，如图片，配置文件等       |
|     ext_modules      |                       指定扩展模块                       |
|       scripts        |   指定可执行脚本,安装时脚本会被安装到系统 PATH 路径下    |
|     package_dir      |          指定哪些目录下的文件被映射到哪个源码包          |
|     entry_points     |              动态发现服务和插件，下面详细讲              |
|   python_requires    |                指定运行时需要的Python版本                |
|       requires       |                     指定依赖的其他包                     |
|       provides       |                指定可以为哪些模块提供依赖                |
|   install_requires   |                  安装时需要安装的依赖包                  |
|    extras_require    |          当前包的高级/额外特性需要依赖的分发包           |
|    tests_require     |                 在测试时需要使用的依赖包                 |
|    setup_requires    |           指定运行 setup.py 文件本身所依赖的包           |
|   dependency_links   |                   指定依赖包的下载地址                   |
|       zip_safe       |              不压缩包，而是以目录的形式安装              |

### 简单的例子

```py setup.py
# coding:utf-8

from setuptools import setup, find_packages
# or
# from distutils.core import setup

setup(
        name='demo',     # 包名字
        version='1.0',   # 包版本
        description='This is a test of the setup',   # 简单描述
        author='Elin',  # 作者
        author_email='365433079@qq.com',  # 作者邮箱
        url='https://github.com/Elinpf',      # 包的主页
        packages=find_packages(),                 # 包
)
```

### 文件的选择和分发

```py setup.py

setup(
    # 安装过程中，需要安装的静态文件，如配置文件、service文件、图片等
    data_files=[
        ('', ['conf/*.conf']),
        ('/usr/lib/systemd/system/', ['bin/*.service']),
                ],

    # 希望被打包的文件
    package_data={
        '':['*.txt'],
        'bandwidth_reporter':['*.txt']
                },
    # 不打包某些文件
    exclude_package_data={
        'bandwidth_reporter':['*.txt']
                }
)
```

### 依赖包的描述

```py setup.py
setup(
    ...

    # 表明当前模块依赖哪些包，若环境中没有，则会从pypi中下载安装
    install_requires=['docutils>=0.3'],

    # setup.py 本身要依赖的包，这通常是为一些setuptools的插件准备的配置
    # 这里列出的包，不会自动安装。
    setup_requires=['pbr'],

    # 仅在测试时需要使用的依赖，在正常发布的代码中是没有用的。
    # 在执行python setup.py test时，可以自动安装这三个库，确保测试的正常运行。
    tests_require=[
        'pytest>=3.3.1',
        'pytest-cov>=2.5.1',
    ],

    # 用于安装setup_requires或tests_require里的软件包
    # 这些信息会写入egg的 metadata 信息中
    dependency_links=[
        "http://example2.com/p/foobar-1.0.tar.gz",
    ],

    # install_requires 在安装模块时会自动安装依赖包
    # 而 extras_require 不会，这里仅表示该模块会依赖这些包
    # 但是这些包通常不会使用到，只有当你深度使用模块时，才会用到，这里需要你手动安装
    extras_require={
        'PDF':  ["ReportLab>=1.2", "RXP"],
        'reST': ["docutils>=0.3"],
    }
)
```

### 安装环境的限制

```py setup.py
setup(
    ...
    python_requires='>=2.7, <=3',
)
```

### 生成可执行文件

```py setup.py
from setuptools import setup, find_packages


setup(
    ...

    # 用来支持自动生成脚本，安装后会自动生成 /usr/bin/foo 的可执行文件
    # 该文件入口指向 foo/main.py 的main 函数
    entry_points={
        'console_scripts': [
            'foo = foo.main:main'
        ]
    },

    # 将 bin/foo.sh 和 bar.py 脚本，生成到系统 PATH中
    # 执行 python setup.py install 后
    # 会生成 如 /usr/bin/foo.sh 和 如 /usr/bin/bar.py
    scripts=['bin/foo.sh', 'bar.py']
)
```

如果想去掉脚本的后缀，可以这样

```py setup.py
from setuptools.command.install_scripts import install_scripts

class InstallScripts(install_scripts):

    def run(self):
        setuptools.command.install_scripts.install_scripts.run(self)

        # Rename some script files
        for script in self.get_outputs():
            if basename.endswith(".py") or basename.endswith(".sh"):
                dest = script[:-3]
            else:
                continue
            print("moving %s to %s" % (script, dest))
            shutil.move(script, dest)

setup(
    ...
    scripts=['bin/foo.sh', 'bar.py'],

    cmdclass={
        "install_scripts": InstallScripts
    }
)
```

## 使用 setup.py 构建包

### 源码包

使用`python setup.py sdist`命令，将源码包打包成一个tar.gz文件，并存放在dist目录中。

使用`easy_install xxx.tar.gz`命令，安装包。

### 二进制包

使用`python setup.py bdist`命令，将生成多个格式的二进制文件，如果想单独生成一种二进制格式：

- `bdist_wininst` windows安装程序
- `bdist_rpm` rpm包
- `bdist_egg` python egg包
- `bdist_wheel` python wheel包

### 指定dist文件夹的位置

`python setup.py sdist  --dist-dir=[path]`

or

`-d [path]`

## 使用 setup.py 安装包

多数情况使用构建包或者pip进行安装，如果需要本地安装：

- `python setup.py install`命令完整安装。

- `python setup.py develop`命令创建软连接，有变化时不必重复安装。


## 如何发布到 PyPI

`python setup.py sdist upload` 命令发布到 PyPI
