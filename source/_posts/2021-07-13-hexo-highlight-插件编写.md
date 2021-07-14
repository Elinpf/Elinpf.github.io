---
title: hexo highlight 插件编写
date: 2021-07-13 16:47:46
tags:
- hexo
categories:
- 前端技术
---

## 插件编写思路

首先要编写hexo的插件需要浏览[官方文档](https://hexo.io/zh-cn/api/)。

编写插件的初衷是因为hexo的代码块有以下几点不足：
1. 对代码块标题的显示不够好
2. 代码块的高亮只能是`{% codeblock mark:2%}`的写法才可以，并不是通用写法。
3. 缺少代码中间添加`highlight-next-line`等注释可以高亮的功能
4. 代码块的html结构不够清晰。

基于此，我们要做的要么是直接修改源码要么就是添加一个插件。


## 编写插件的准备工作

新创建一个`hexo`实例后，在`node_modules`文件夹下新建一个以`hexo-`开头的文件夹。我的为`hexo-highlight-mark`。
然后进入文件夹中执行`npm init`来初始化npm包，这里的问答可以直接一路回车，后面再在`package.json`中修改。

新建`index.js`文件作为入口文件。

在根目录中的`package.json`文件中添加插件的名称和版本号，此时插件就可以以最小单位运行了。

## 如何修改代码块结构

这个插件要修改代码块的结构，可以用到[过滤器](https://hexo.io/zh-cn/api/filter)。

```js title:index.js
'use strict';

hexo.extend.filter.register('before_post_render', require('./lib/filter'), 8);
```

`before_post_render`是过滤器在文章渲染之前就介入执行。

```js title:./lib/filter.js
const rBacktick = /^((?:[^\S\r\n]*>){0,3}[^\S\r\n]*)(`{3,}|~{3,})[^\S\r\n]*((?:.*?[^`\s])?)[^\S\r\n]*\n((?:[\s\S]*?\n)?)(?:(?:[^\S\r\n]*>){0,3}[^\S\r\n]*)\2[^\S\r\n]?(\n+|$)/gm;

module.exports = function (data) {
    const dataContent = data.content;

    if ((!dataContent.includes('```') && !dataContent.includes('~~~')) || (!hljsCfg.enable && !prismCfg.enable)) return;

    // highlight-start
    data.content = dataContent.replace(rBacktick, ($0, start, $2, _args, _content, end) => {
        // do something
    }
    // highlight-end
}
```

上面的代码就是将`data.content`中的代码块部分进行匹配并且自定义渲染并返回替换原内容。

## 调试

配置调试文件如下：

```json title:.vscode/launch.json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "pwa-node",
            "request": "launch",
            "name": "Launch Program",
            "program": "${workspaceFolder}\\node_modules\\hexo\\bin\\hexo",
            "args": [
                "g",
                "--debug"
            ],
            // highlight-next-line
            "preLaunchTask": "npm: clean"
        }
    ]
}
```

配置前置任务，清除原有的数据

```json title:.vscode/tasks.json
{
	"version": "2.0.0",
	"tasks": [
		{
			"type": "npm",
            // highlight-next-line
			"script": "clean",  // 名称必须相同，大小写敏感
			"problemMatcher": [],
			"label": "npm: clean",
			"detail": "hexo clean"
		}
	]
}
```

## 发布到npm

要发布npm，需要注册[npm账号](www.npmjs.com)

然后在插件文件夹修改好`package.json`然后运行登录和发布命令即可

```bash
npm login  # 登录
npm publish  # 发布文件
```
