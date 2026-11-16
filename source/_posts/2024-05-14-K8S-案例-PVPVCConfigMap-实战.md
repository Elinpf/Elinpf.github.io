---
title: K8S 案例：PV/PVC/ConfigMap 实战
date: 2024-05-14 11:00:47
tags:
- k8s
- pvc
- configmap
categories:
- 运维
- K8S
---

## PV & PVC & StatefulSet

```YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mypv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  storageClassName: local  # 这里指定了类型，要不然会自动创建
  persistentVolumeReclaimPolicy: Retain
  hostPath:  
    path: /tmp

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc
spec:
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  serviceName: myapp
  replicas: 2
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: busybox:latest
        
        command: ["/bin/sh"]
        args:
          - -c
          - >-
            echo "hello" > /tmp/my-data/1.txt &&
            sleep 600
        volumeMounts:
        - name: my-data
          mountPath: /tmp/my-data
      volumes:
      - name: my-data
        persistentVolumeClaim:
          claimName: mypvc
```

这个案例中，手动创建了PV，PVC，并进行了关联。

从结果上来看，只创建了一个PV和一个PVC

但是每个pod节点上面的/tmp目录中，都存在1.txt文件。也就是说明，这个PV其实是在每台node上面都申请了，并且进行了Mount

## 自动申请分配PV和PVC

```YAML
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es7-cluster
  namespace: elk
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.8.1
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      # storageClassName: "huawei-san" #根据实际情况而定
      resources:
        requests:
          storage: 1Gi
```

## 通过configmap，获取配置文件

```YAML
kubectl create configmap nginx-config --from-file=nginx.conf

# 更新
kubectl replace configmap nginx-config --from-file=nginx.conf
```

然后再通过下面的方式进行挂载

```YAML
volumeMounts:  
- name: nginx-config-volume  
  mountPath: /etc/nginx/nginx.conf  
  subPath: nginx.conf  
volumes:  
- name: nginx-config-volume  
  configMap:  
    name: nginx-config  
    items:  
    - key: nginx.conf  
      path: nginx.conf
```

**volumeMounts**

`volumeMounts` 部分定义了如何将存储卷（Volume）挂载到容器内的文件系统上。

- `name`: 指定了要挂载的存储卷的名称，这里是 `nginx-config-volume`。
- `mountPath`: 容器内部的路径，即存储卷将被挂载到的位置。在这里，`/etc/nginx/nginx.conf` 表示 Nginx 配置文件将被挂载到这个位置，覆盖原有的文件（如果有的话）。
- `subPath`: 这是一个非常有用的字段，它允许你从存储卷中选择一个特定的文件或子目录来挂载，而不是挂载整个存储卷。在这个例子中，`subPath: nginx.conf` 表示仅挂载名为 `nginx-config` 的 ConfigMap 中 `nginx.conf` 这个键对应的文件内容到容器的 `/etc/nginx/nginx.conf` 路径。
**volumes**

`volumes` 部分定义了哪些存储卷可供挂载。

- `name`: 存储卷的名称，与 `volumeMounts` 中的 `name` 相对应，这里是 `nginx-config-volume`。
- `configMap`: 指定了该存储卷是一个 ConfigMap 类型的存储卷。
  - `name`: ConfigMap 的名称，这里是 `nginx-config`。
  - `items`: 这是一个可选字段，允许你指定 ConfigMap 中的哪些项（即键值对）应该被包含在存储卷中。
    - `key`: ConfigMap 中的键名，这里是 `nginx.conf`。
    - `path`: 在存储卷中，这个文件应该被命名为什么。因为使用了 `subPath`，所以这个 `path` 实际上在挂载时不会直接体现在容器的文件系统中，但它确保了只有 `nginx.conf` 这个键的内容被包含在存储卷中。
**subPath 的作用**

`subPath` 的主要用途是在你只需要挂载存储卷中的某个特定文件，而不是整个存储卷时，能够非常精确地控制挂载的内容。在这个例子中，由于 Nginx 配置文件通常是一个单独的文件，所以使用 `subPath` 可以确保只有这个文件被挂载到容器中，而不是整个 ConfigMap 的内容。

简而言之，`subPath` 允许你指定要挂载的存储卷中的一个具体文件或目录，而不是整个存储卷。这在很多场景下都非常有用，特别是当存储卷中包含多个文件或目录，而你只需要挂载其中一个时。

### 多个配置文件创建一个configmap并进行调用

可以通过引入目录，或者多次调用`--from-file`参数来实现

```YAML
kubectl create configmap nginx-config --from-file=path/to/config/directory/
```

然后使用subPath进行精确调用

```YAML
apiVersion: v1  
kind: ConfigMap  
metadata:  
  name: nginx-configs  
data:  
  nginx.conf: |  
    # nginx configuration  
  fastcgi_params: |  
    # fastcgi_params configuration  
---  
apiVersion: apps/v1  
kind: Deployment  
metadata:  
  # ...  
spec:  
  template:  
    spec:  
      containers:  
        - name: nginx  
          # ...  
          volumeMounts:  
            - name: nginx-config-volume  
              mountPath: /etc/nginx/nginx.conf  
              subPath: nginx.conf  
            - name: nginx-config-volume  
              mountPath: /etc/nginx/fastcgi_params  
              subPath: fastcgi_params  
      volumes:  
        - name: nginx-config-volume  
          configMap:  
            name: nginx-configs
```

### 如果更新configmap

1. 生成一个新的 configmap.yaml文件
```YAML
kubectl create configmap nginx-config --from-file=path/to/config/directory/ --dry-run=client -o yaml > configmap.yaml
```

1. 替换
```YAML
kubectl replace -f configmap.yaml
```
