---
title: 离线环境安装 NVIDIA Container Toolkit
date: 2025-07-18 09:34:53
tags:
- nvidia
- container-toolkit
- 离线安装
categories:
- 运维
---

## 环境准备

- 已正确安装对应GPU驱动
- NVIDIA drivers ~= 384.81
- nvidia-docker >= 2.0 || nvidia-container-toolkit >= 1.7.0
- nvidia-container-runtime configured as the default low-level runtime
- Kubernetes version >= 1.10

## 包文件安装

- 根据对应系统环境下载[离线安装包](https://github.com/NVIDIA/libnvidia-container/tree/gh-pages/stable/ubuntu18.04/amd64)
- 各包文件依赖关系

- 安装顺序
  - ibnvidia-container
  - libnvidia-container-tools
  - nvidia-container-toolkit
  - nvidia-container-runtime
- 配置docker环境则需要安装nvidia-docker2并配置nvidia-container-runtime
```Bash
vim /etc/docker/daemon.json
{"default-runtime":"nvidia","runtimes": {"nvidia": {"path":"/usr/bin/nvidia-container-runtime","runtimeArgs": []
        }
    }
}
systemctl restart docker
```

- 配置containerd环境
```Bash
vim /etc/containerd/config.toml
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "nvidia"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
    privileged_without_host_devices = false
    runtime_engine = ""
    runtime_root = ""
    runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
      BinaryName = "/usr/bin/nvidia-container-runtime"
systemctl restart containerd
            
```
