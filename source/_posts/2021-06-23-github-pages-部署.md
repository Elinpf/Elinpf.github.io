---
title: 使用 Github Pages 部署 Blog
tags: 
- github
- docusaurus
---

# 使用 Github Pages 部署 Blog

要使用 Github Pages 来部署博客，首先需要选择使用什么静态框架。

这里我最终选择了[Docusaurus](https://docusaurus.io/zh-CN/docs)

开发与部署的简要流程如下：
1. 使用`Docusaurus`的脚手架创建初始项目
```
npx @docusaurus/init@latest init my-website classic
```

2. 修改`docusaurus.config.js`文件中3个重要内容

```js
    url: 'https://elinpf.github.io',
    organizationName: 'Elinpf', 
    projectName: 'elinpf.github.io', 
```

3. 在Github上创建同名仓库`Elinpf/Elinpf.github.io`

4. 发布`master`和`gh-pages`分支

```bash
git remote add origin https://github.com/Elinpf/Elinpf.github.io.git
git push origin master
git branch -M gh-pages
git push origin gh-pages
```

5. 将`Setting`中的Pages发布源改为`gh-pages`分支

![](1.png)

6. 将`Setting`中的`Secrets`添加一个`ACCESS_TOKEN`(这里的token就是用户授权的token值，[参考这里增加新的授权](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token))

![](2.png)

7. 在项目中添加文件`.github/workflows/docusaurus.yml`，来写Action用于自动部署（具体含义参考[这篇文章](http://www.ruanyifeng.com/blog/2019/09/getting-started-with-github-actions.html)）

```yaml title=".github/workflows/docusaurus.yml"
name: Deploy Github pages
on:
  push:
    branches:
      - master
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@master
      with:
        persist-credentials: false
    - name: Install and Build
      run: |
        npm install
        npm run-script build 
    - name: Deploy
      uses: JamesIves/github-pages-deploy-action@releases/v3
      with:
        ACCESS_TOKEN: ${{ secrets.ACCESS_TOKEN }}
        BRANCH: gh-pages
        FOLDER: build
        BUILD_SCRIPT: npm install && npm run build
```

8. 再次提交就可以了