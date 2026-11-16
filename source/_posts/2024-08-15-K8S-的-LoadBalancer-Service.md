---
title: K8S 的 LoadBalancer Service
date: 2024-08-15 14:25:49
tags:
- k8s
- metallb
categories:
- 运维
- K8S
---

## 参考

- [Kubernetes LoadBalancer Service 与负载均衡器](https://atbug.com/k8s-service-and-load-balancer/)
- [在 Kubernetes 集群中使用 MetalLB 作为 LoadBalancer（上）- Layer2](https://atbug.com/load-balancer-service-with-metallb/)
- [在 Kubernetes 集群中使用 MetalLB 作为 LoadBalancer（下）- BGP](https://atbug.com/load-balancer-service-with-metallb-bgp-mode/)

## Loadbalancer

在k8s中，一直对loadbalancer这个svc搞不懂，官方文档也就是写了个要和云厂商的负载均衡器进行联动配置。但是具体是什么，为什么。以及原理都语焉不详

在看了上面的参考文章后，有了一定的了解

所谓的Service，就是将一堆相同的Pod，按照一样的策略对外暴露的服务

而Loadbalancer就是其中的一种策略，**通过和负载均衡器的交互，获取external-ip**，然后根据配置的后端地址和端口，进行转发

## Metal LB

MetalLB 是裸机 Kubernetes 集群的负载均衡器实现，使用标准路由协议。

主要有两个部分构成，speaker和controller，

- Speaker是DaemonSet，对外宣告Service的IP
- Controller是Deployment，监听Service的变化

主要提供的功能：

1. 地址分配，通过ARP查询到配置的地址池中空闲的IP，进行分配
2. 对外宣告，通过BGP将IP宣告到网络中。或者只是二层广播ARP
3. 将分配的地址告诉SVC，后面就是通过kubeproxy来进行集群内部pod的通讯了

单一使用负载均衡也会有一个缺点，就是会有单点瓶颈
