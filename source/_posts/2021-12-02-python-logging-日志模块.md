---
title: python logging 日志模块
date: 2021-12-02 10:14:54
tags:
categories:
---

- [日志常用指引](https://docs.python.org/zh-cn/3/howto/logging.html#logging-basic-tutorial)


## 日志级别


|   级别   |                               何时使用                               |
| :------: | :------------------------------------------------------------------: |
|  DEBUG   |                    细节信息，仅当诊断问题时适用。                    |
|   INFO   |                         确认程序按预期运行。                         |
| WARNING  | 表明有已经或即将发生的意外（例如：磁盘空间不足）。程序仍按预期进行。 |
|  ERROR   |            由于严重的问题，程序的某些功能已经不能正常执行            |
| CRITICAL |                  严重的错误，表明程序已不能继续执行                  |

## 初级使用

```py
import logging
logging.warning('Watch out!')  # will print a message to the console
logging.info('I told you so')  # will not print anything
```

记录到文件

```py
import logging
logging.basicConfig(filename='example.log', encoding='utf-8', level=logging.DEBUG)
logging.debug('This message should go to the log file')
logging.info('So should this')
logging.warning('And this, too')
logging.error('very bad')
```

## logging的组件

logging采用组件的方式组合使用

logging 模块的四大组件

|    组件    |                          说明                          |
| :--------: | :----------------------------------------------------: |
|  loggers   |             提供应用程序代码直接使用的接口             |
|  handlers  |   处理器将日志记录（由记录器创建）发送到适当的目标。   |
|  filters   | 过滤器提供了更细粒度的功能，用于确定要输出的日志记录。 |
| formatters |             用于控制日志信息的最终输出格式             |


### 记录器 logger

记录器的三个任务
1. 记录器对程序公开了几个接口，可以用于记录日志信息
2. 根据严重程度或者过滤器确定是否记录日志
3. 将记录的日志发送给处理器handler

常用的接口:
- `Logger.getLogger()`
- `Logger.setLevel()`
- `Logger.addHandler()` 与 `Logger.removeHandler()`
- `Logger.addFilter()` 与 `Logger.removeFilter()`

以及记录日志信息方法：
- `Logger.debug()`
- `Logger.info()`
- `Logger.warning()`
- `Logger.error()`
- `Logger.exception()`

其中`Logger.exception()`和`Logger.error()`的区别是，前者会自动记录异常信息，后者不会。

在命名记录器时使用的一个好习惯是在每个使用日志记录的模块中使用模块级记录器，命名如下:

`Logger.getLogger(__name__)`

多次调用`getLogger()`具有相同的名称将返回对同一记录器对象的引用。

### 处理器 handler

hanlder将适当的（根据日志消息的严重性）日志记录发送的指定的目标。

> 作为示例场景，应用程序可能希望将所有日志消息发送到日志文件，将错误或更高的所有日志消息发送到标准输出，以及将所有关键消息发送至一个邮件地址。 此方案需要三个单独的处理器，其中每个处理器负责将特定严重性的消息发送到特定位置。

标准库中包含很多处理器，常用的有`StreamHandler`和`FileHandler`。更多的处理器可以在[这里](https://docs.python.org/zh-cn/3/howto/logging.html#useful-handlers)找到。

常用的接口：

- `Handler.setLevel()` 和 `Logger.setLevel()`不同，`Logger`的是发送给Handler的最低严重性，而`Hander`的是发送给目标的最低严重性。
- `Handler.setFormatter()`
- `Handler.addFilter()` 与 `Handler.removeFilter()`

### 格式器 formatter

标准格式如下:

```py
logging.Formatter.__init__(fmt=None, datefmt=None, style='%')
```

三个可选项分别是`消息格式字符串`、`日期格式字符串`和`样式指示符`。

```py
fmt='%(asctime)s - %(levelname)s - %(message)s'
```


## 配置日志记录

### 代码配置日志记录

```py
import logging

# create logger
logger = logging.getLogger('simple_example')
logger.setLevel(logging.DEBUG)

# create console handler and set level to debug
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)

# create formatter
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# add formatter to ch
ch.setFormatter(formatter)

# add ch to logger
logger.addHandler(ch)

# 'application' code
logger.debug('debug message')
logger.info('info message')
logger.warning('warn message')
logger.error('error message')
logger.critical('critical message')
```

### yaml配置日志记录

```py log.py
import logging
import logging.config
import yaml

from lib.data.data import pystr


def setup_logger() -> logging.Logger:
    with open('logconf.yaml') as f:
        config = yaml.safe_load(f.read())
        logging.config.dictConfig(config)
        logger = logging.getLogger('simpleExample')

    return logger

logger = setup_logger()
```

```yaml logging.yaml
version: 1
formatters:
  simple:
    format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    level: INFO
    formatter: simple
    stream: ext://sys.stdout
  debug_file_handler:
    class: logging.handlers.RotatingFileHandler
    level: DEBUG
    formatter: simple
    filename: ./log/debug.log
    maxBytes: 10485760 # 10MB
    backupCount: 20
error_file_handler:
    class: logging.handlers.RotatingFileHandler
    level: ERROR
    formatter: simple
    filename: ./log/error.log
    maxBytes: 10485760 # 10MB
    backupCount: 20
    encoding: utf8
loggers:
  pyaio:
    level: DEBUG
    handlers: [console, debug_file_handler, error_file_handler]
    propagate: no
root:
  level: DEBUG
  handlers: [console]   encoding: utf8
```
