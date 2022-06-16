---
title: git CHANGELOG 规范
date: 2022-05-23 10:19:20
tags:
- git
categories:
- 编程
---

## 约定式提交

- [参考文章](https://www.conventionalcommits.org/zh-hans/v1.0.0/)

CHANGELOG的本质就是需要遵守约定式提交，约定式提交规范是一种基于提交信息的轻量级约定。 它提供了一组简单规则来创建清晰的提交历史； 这更有利于编写自动化工具。 通过在提交信息中描述功能、修复和破坏性变更， 使这种惯例与[SemVer](https://semver.org/)相互对应。

### 为什么使用约定式提交

- 自动化生成 CHANGELOG。
- 基于提交的类型，自动决定语义化的版本变更。
- 向同事、公众与其他利益关系者传达变化的性质。
- 触发构建和部署流程。
- 让人们探索一个更加结构化的提交历史，以便降低对你的项目做出贡献的难度。

### commit 规范

每次提交，Commit message 都包括三个部分：Header，Body 和 Footer。

```txt
<type>(<scope>): <subject> 
// 空一行 
<body> 
// 空一行 
<footer>
复制代码
```

其中，Header 是必需的，Body 和 Footer 可以省略。


1. type的类型

- feat：新功能（feature）
- fix：修补 bug
- docs：文档（documentation）
- style： 格式（不影响代码运行的变动）
- refactor：重构（即不是新增功能，也不是修改 bug 的代码变动）
- test：增加测试
- chore：构建过程或辅助工具的变动(CI)
- perf: 提升性能

2. scop 

用于说明 commit 影响的范围，比如数据层、控制层、视图层等等，视项目不同而不同。

3. subject

subject 是 commit 目的的简短描述，不超过 50 个字符。

- 以动词开头，使用第一人称现在时，比如 change，而不是 changed 或 changes
- 第一个字母小写
- 结尾不加句号（.）

```txt
<type>(<scope>): <short summary>
  │       │             │
  │       │             └─⫸ Summary in present tense. Not capitalized. No period at the end.
  │       │
  │       └─⫸ Commit Scope: The scope should be the name of the component affected
  │                           (as perceived by the person reading the 
  │                          changelog generated from commit messages).
  │
  └─⫸ Commit Type: build|ci|docs|feat|fix|perf|refactor|test
```

### VScode 插件

推荐使用`git-commit-plugin`这个插件