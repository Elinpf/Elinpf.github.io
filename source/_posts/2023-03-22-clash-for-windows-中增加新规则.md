---
title: clash for windows 中增加新规则
date: 2023-03-22 08:55:45
tags:
- tool
categories:
---

clash for windows 中如果想要在不改变原有的YAML文件下，增加自己的新规则，不能使用MIXIN这个混合模式，因为这个模式下，clash for windows 会自动将原有的YAML文件中的规则全部删除，只保留自己的规则。

而是应该使用配置文件预处理。

[](1.png)

首先在`Settings`中复制`URL`出来，然后选择`Parsers`进行编辑。

以添加`openai.com`的规则为例，添加如下的规则

```yaml
parsers:
  - url: <复制出来的URL>
    yaml:
      prepend-rules:
        - DOMAIN-SUFFIX,openai.com,🌎 全球代理
```

其中：
- `url`是复制出来的URL
- `prepend-rules` 数组合并至原配置rules数组前, 更多的配置可以参考[这里](https://docs.cfw.lbyczf.com/contents/parser.html#%E5%8F%82%E6%95%B0%E8%AF%B4%E6%98%8E)
- `DOMAIN-SUFFIX,openai.com,🌎 全球代理` 是要添加的规则
    - `DOMAIN-SUFFIX` 是规则类型, 更多的规则类型可以参考[这里](https://docs.cfw.lbyczf.com/contents/ui/profiles/rules.html)
    - `openai.com` 是要匹配的域名
    - `🌎 全球代理` 是要使用的代理组

完成配置后需要将整个规则重新**更新**一次才能生效。

更新完后，可以在配置里面看到刚刚添加的内容已经合并进来了。