---
title: Kubernetes 学习笔记
date: 2024-04-09 16:09:27
tags:
- k8s
- yaml
categories:
- 运维
- K8S
---

## 命令

```Bash
## api 解释
 kubectl explain pod.spec
```

## 参考文档

- [API 参考](https://kubernetes.io/zh-cn/docs/reference/kubernetes-api/workload-resources/deployment-v1/)
- [学习文档](https://www.qikqiak.com/k8strain/basic/yaml/)
- [资源清单 - K8S训练营](https://www.qikqiak.com/k8strain/basic/yaml/)
## Kubernetes学习框架

Kubernetes（简称K8s）是Google开源的一个容器编排系统，用于自动化容器化应用的部署、扩展和管理。学习Kubernetes，主要可以分为以下几个关键点：

1. **基本概念**：
   - **Pod**：Kubernetes的基本工作单元，一个Pod可以包含一个或多个紧密相关的容器。
   - **Service**：定义一组Pod的逻辑集合，并提供一个稳定的网络端点来访问它们。
   - **Deployment**：用于声明式地更新应用的副本数量，以及更新策略。
   - **ReplicaSet**：保证任意时刻都有指定数量的Pod副本运行。
   - **ConfigMap/Secret**：用于存储和管理应用的配置信息和敏感数据。
   - **Namespace**：用于逻辑上划分集群资源，实现多租户。
2. **集群搭建**：
   - **Master节点**：运行控制平面组件，如etcd、apiserver、controller-manager、scheduler等。
   - **Worker节点**：运行kubelet和container runtime，执行实际的工作负载。
   - **网络模型**：Kubernetes要求每个Pod有自己的IP，且Pod间通信无需NAT。
3. **应用部署**：
   - 使用`kubectl`命令行工具或者YAML/JSON配置文件进行应用部署。
   - 了解`kubectl run`、`kubectl apply`、`kubectl expose`等常用命令。
4. **服务发现和负载均衡**：
   - Service通过Label Selector选择一组Pod，提供负载均衡和内部DNS服务。
   - NodePort、LoadBalancer、ClusterIP等Service类型用于对外暴露服务。
5. **扩展和更新**：
   - 使用Deployment进行滚动更新或蓝绿部署。
   - 利用Horizontal Pod Autoscaler（HPA）实现自动扩缩容。
6. **存储**：
   - PersistentVolume（PV）和PersistentVolumeClaim（PVC）用于管理持久化存储。
7. **安全与认证**：
   - 使用ServiceAccount进行权限控制。
   - 了解RBAC（Role-Based Access Control）进行细粒度的权限管理。
8. **监控与日志**：
   - 使用Kubernetes的metrics-server、Prometheus、Grafana等工具进行集群监控。
   - 使用Kubernetes的logging机制收集和查看Pod日志。
9. **故障排查**：
   - 使用`kubectl get`、`kubectl describe`、`kubectl logs`等命令进行问题排查。
10. **最佳实践**：
   - 如何设计可扩展、可维护的Kubernetes应用。
   - 如何优化资源使用，避免资源浪费。
以上是Kubernetes学习的基本框架，深入学习还需要结合实际操作和项目经验。

### kind字段

kind字段主要用于Kubernetes资源定义，它表示资源的类型

#### pod

Kubernetes的基本执行单元，包含一个或多个容器。

```YAML
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: my-container
    image: nginx:latest
```

#### Deployment

管理无状态应用的副本，用于管理Pod的复制集，可以自动创建、更新和回滚Pod。

```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19.10
```

#### Service

定义访问Pod的策略，通常涉及到负载均衡和网路路由。

为一组Pod提供一个稳定的网络标识和负载均衡。

```YAML
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

**常用字段**

- **spec.ports.port 和 spec.ports.targetPort**
port是对外暴露的服务端口，一个是对内pod的接受端口，是一个映射关系

- **type 字段**
是 kind 为 Service里面的概念

1. ClusterIP
   1. 默认服务类型
   2. 集群内部分配一个并访问
2. NodePort
   1. 对外提供一个NodeIP和NodePort
   2. 端口必须是在30000-32767范围内
   3. 可以手动分配，也可以自动分配，但是要注意不能被占用了
3. LoadBalancer
   1. 当使用云厂商来托管k8s集群时
4. ExternalName
   1. 允许映射到外部域名
#### StatefulSet

用于管理有状态应用的Pod集合，如数据库或需要持久存储的应用。

```YAML
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-statefulset
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:5.7
```

#### ConfigMap

存储非敏感的配置数据，可以被挂载或者注入到环境变量

用于存储非结构化数据，如配置文件或环境变量。

```YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
data:
  special.how: very
  special.type: charm
```

#### Secret

存储敏感信息，入密码、OAuth tokens和ssh keys

```YAML
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
data:
  password: dmFsdWUtMg0K # base64 encoded value
```

#### Ingress

定义外部访问Kubernetes服务的规则，通常用于HTTP/HTTPS路由。

通过域名和URL路径将不通的外部请求路由到不同的服务，类似nginx。但是ingress是k8s的集成组件，配合的更加紧密

```YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-wildcard-host
spec:
  rules:
  - host: "foo.bar.com"
    http:
      paths:
      - pathType: Prefix
        path: "/bar"
        backend:
          service:
            name: service1
            port:
              number: 80
  - host: "*.foo.com"
    http:
      paths:
      - pathType: Prefix
        path: "/foo"
        backend:
          service:
            name: service2
            port:
              number: 80
```

#### Job

一次性或定期运行的Pod

#### CronJob

定期运行的Job

#### DaemonSet

确保所有（或某些）节点上都运行一个Pod的副本

#### PersistentVolume

在集群中持久化的存储资源

#### PersistentVolumeClaim

Pod请求使用持久化存储的声明

#### Namespace

用于组织Kubernetes资源的命名空间

#### ServiceAccount

为Pod提供身份验证和授权的账户

## PV 和 PVC

PV（PersistentVolume）和PVC（PersistentVolumeClaim）在Kubernetes存储中起着不同的作用，它们之间的主要区别如下：

1. **概念和角色**：
   - **PV（PersistentVolume）**：持久化卷，是对底层的共享存储的一种抽象。它是由管理员配置的，代表集群中的一段网络存储，可以被一个或多个PVC申请使用。
   - **PVC（PersistentVolumeClaim）**：持久卷请求，是用户对存储资源的需求声明。用户通过PVC来请求特定大小和访问模式的存储。
2. **使用逻辑**：
   - **PV**：通常由Kubernetes管理员创建和配置，作为可用的存储资源池。
   - **PVC**：由用户（开发者或应用所有者）创建，用于表达他们对存储资源的需求。PVC必须与对应的PV建立关系，即PVC会根据定义去申请合适的PV。
关于StatefulSet和PVC/PV的关系：

- 在StatefulSet中，通常会为每个Pod定义一个PVC，以确保每个Pod都有自己独立的持久化存储。
- **如果StatefulSet中定义了PVC，那么确实需要相应的PV来满足这些PVC的需求**。没有可用的PV，PVC将无法满足存储请求，Pod可能无法正确启动或运行。
总结来说，PV和PVC是Kubernetes中存储资源的管理和申请机制。PV是实际的存储资源，而PVC是用户对存储资源的需求申请。在StatefulSet中使用PVC时，需要确保有相应的PV来满足存储需求。

### 预绑定

- [Kubernetes PV 和 PVC 绑定流程及预绑定 (Pre-Binding) - 知乎](https://zhuanlan.zhihu.com/p/166272609)
PV和PVC绑定大多时候都是自动匹配的，但是当需要明确进行绑定时，可以采用预绑定的方案

- 在 PV 的 **Spec.ClaimRef** 写下 PVC 的 Namespace 和 Name 后，可以让 PV 为该 PVC 预留，而不让其他 PVC 申请到。
- 在 PVC 的 **Spec.VolumeName** 写下 PV 的 Name ，可以指定与该 PV 进行预绑定
实际使用中，需结合具体需求采取一种方法，或两种方法同时进行预绑定操作。

### 多条command 命令

```YAML
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:  # specification of the pod’s contents
  restartPolicy: Never
  containers:
  - name: hello
    image: "ubuntu:14.04"
    command: ["/bin/sh"]
    args:
      - -c
      - >-
          command1 arg1 arg2 &&
          command2 arg3 &&
          command3 arg4
```

### 滚动更新

```YAML
kubectl rollout restart sts xxx -n xxxx
```

### 如何驱逐一个node

要对一个Kubernetes集群中的节点进行驱逐，可以按照以下步骤进行：

1. **确定要驱逐的节点**：
   首先，你需要确定你想要驱逐的节点的名称。你可以使用`kubectl get nodes`命令来获取集群中所有节点的列表和它们的状态。
2. **标记节点为不可调度**：
   在驱逐节点之前，你应该先将其标记为不可调度，以防止Kubernetes调度器将新的Pod调度到该节点上。你可以使用`kubectl cordon <node-name>`命令来实现这一点，其中`<node-name>`是你要驱逐的节点的名称。
3. **驱逐节点上的Pod**：
   接下来，你需要驱逐该节点上的所有Pod。这可以通过`kubectl drain <node-name> --delete-local-data --force --ignore-daemonsets`命令来完成。这个命令会尝试将节点上的所有Pod驱逐到其他可用的节点上，并且会删除节点上的所有本地数据（除了DaemonSet管理的Pod，这些Pod会被忽略）。

   - `--delete-local-data`：表示删除节点上的本地数据卷。
   - `--force`：强制执行驱逐操作，即使这可能会导致服务中断。
   - `--ignore-daemonsets`：在驱逐过程中忽略DaemonSet管理的Pod，因为这些Pod通常与节点紧密相关。
4. **确认节点已被驱逐**：
   完成上述步骤后，你应该再次运行`kubectl get nodes`命令来确认节点已经被成功驱逐。被驱逐的节点将不再显示有运行的Pod（除了DaemonSet管理的Pod）。
5. **后续操作**：
   在节点被驱逐后，你可以根据需要进行进一步的操作，比如对该节点进行维护、升级或者从集群中移除等。
请注意，在执行驱逐操作之前，务必确保集群中有足够的资源来容纳从被驱逐节点上迁移过来的Pod，以避免服务中断或资源不足的情况。同时，也应该考虑到驱逐操作可能对正在运行的服务造成的影响，并提前做好相应的准备工作。

此外，Kubernetes还提供了更细粒度的驱逐策略和控制选项，例如通过配置Pod的优先级和QoS类别来影响驱逐的顺序等。这些高级功能可以根据具体的需求和场景进行配置和使用。
