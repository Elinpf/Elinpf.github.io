---
title: javascript 的export导出方式
date: 2021-07-15 09:26:54
tags:
categories:
- 编程
- javascript
---

## javascript 的两种格式

javascript 中有两种格式模块
   
1. Nodejs 的 `CommonJS`模块，简称`CJS`
2. ES6模块，简称`ESM`

引入的方式区别如下：

![](1.png)

CJS的导出都是`exports`，而`ESM`的导出都是`export`

## CJS 的引入

使用两个文件来做测试，`utils.js` 和 `test.js`

### module.exports

```js title:utils.js
const a = (x, y) => x + y;
const b = (x, y) => x + y;
module.exports = a;
module.exports = b;
```

```js title:test.js
const utils = require('./utils');
console.log(utils); // [Function: b]
```

可以看到，这种方法只能导出一个函数

### exports

```js title:utils.js
exports.a = (x, y) => x + y;
exports.b = (x, y) => x - y;
```

```js title:test.js
const utils = require('./utils');
console.log(utils); //{ a: [Function (anonymous)], b: [Function (anonymous)] }
```

这种方法可以导出多个函数

