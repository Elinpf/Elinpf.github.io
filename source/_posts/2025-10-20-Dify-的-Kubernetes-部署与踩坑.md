---
title: Dify 的 Kubernetes 部署与踩坑
date: 2025-10-20 14:49:11
tags:
- dify
- k8s
- 部署
categories:
- 大模型
- K8S
---

## 参考

[https://github.com/douban/charts/tree/master/charts/dify](https://github.com/douban/charts/tree/master/charts/dify)

[部署官方问题](https://docs.dify.ai/zh-hans/learn-more/faq/install-faq)

## 部署

关键点：

1. 使用helm进行部署，注意需要使用kubectl apply -n <ns> ，因为dify 的helm很多没有配置namespace
2. dify-api 默认监听的是 5001，但是dify-api-svc 使用的是80，需要改正
3. minio等都使用的是http
4. 有CORS跨域的问题，需要每个deployment中都修改，如果是https，那么下面的都要换成https
```YAML
        - name: CONSOLE_API_URL
          value: https://dify-test2-api.example.com
        - name: CONSOLE_WEB_URL
          value: https://dify-test2.example.com
        - name: SERVICE_API_URL
          value: https://dify-test2-api.example.com
        - name: APP_API_URL
          value: https://dify-test2-api.example.com
        - name: APP_WEB_URL
          value: https://dify-test2.example.com
```

1. pg数据库，可以使用cephfs的模式，然后需要同步数据库一下，官方文档有，如果不行，删掉pv重新试一试
   1.   dify-api 中执行`flask db upgrade`，如果发生错误
   2. statefulset缩容到0，删除pv和pvc， 再加到1
   3. 再执行数据库融合
2. 添加向量数据库milvus
```YAML
            - name: VECTOR_STORE
              value: milvus
            - name: MILVUS_URI
              value: http://172.16.1.41:31382
            - name: MILVUS_USER
              value: root
            - name: MILVUS_PASSWORD
              value: Milvus
```
