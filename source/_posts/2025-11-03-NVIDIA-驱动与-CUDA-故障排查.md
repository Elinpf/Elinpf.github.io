---
title: NVIDIA 驱动与 CUDA 故障排查
date: 2025-11-03 11:40:23
tags:
- gpu
- cuda
- 驱动
categories:
- 运维
---

本文把 NVIDIA 驱动、CUDA、容器运行时（Docker/Containerd）和 K8s GPU Operator 的常用排查命令按主题整理成一份速查手册。

---

# 🧩 一、NVIDIA 驱动管理与卸载

查看驱动版本

```Bash
cat /proc/driver/nvidia/version
```

### 🧱 模块卸载类命令

```Bash
lsmod | grep nvidia

rmmod nvidia_drm
rmmod nvidia_modeset
rmmod nvidia_uvm
rmmod nvidia
modprobe -r nvidia_uvm
```

**作用：**

卸载内核中的 NVIDIA 模块（驱动加载到内核时会生成模块）。

在重新安装驱动或修复冲突时，需要先卸载旧模块。

> ⚠️ 前提：所有使用 GPU 的进程必须先关闭，否则会“Device busy”。

---

### 🔍 GPU 进程与设备占用排查

```Bash
lsof -n -w /dev/nvidia*
fuser /dev/nvidia*
nvidia-smi
```

**作用：**

- `lsof` / `fuser` 查看哪些进程正在占用 `/dev/nvidia*` 设备文件。
- `nvidia-smi` 用于显示 GPU 使用状态（进程列表、显存占用等）。
---

### 💀 强制结束占用进程

```Bash
kill -9 <PID>
```

**作用：**

强制终止占用 GPU 的进程，释放设备文件。

---

# 💾 二、NVIDIA 驱动安装与维护

### 📥 下载并安装官方驱动

```Bash
wget https://cn.download.nvidia.com/.../NVIDIA-Linux-x86_64-570.195.03.run
chmod +x NVIDIA-Linux-x86_64-570.195.03.run
bash ./NVIDIA-Linux-x86_64-570.195.03.run
```

**作用：**

- 下载 `.run` 安装包（官方离线安装器）。
- 执行安装，编译内核模块并注册驱动。
- 安装完可用 `nvidia-smi` 验证是否正常。
---

### 🧹 卸载旧版本

```Bash
./NVIDIA-Linux-x86_64-570.195.03.run --uninstall
```

**作用：**

卸载旧版驱动，防止与新版本冲突。

---

### 🔧 修复损坏的包系统

```Bash
apt --fix-broken install
dpkg --configure -a
apt autoremove -y
```

**作用：**

修复因手动安装 `.run` 包、DKMS 编译错误等导致的依赖残留或中断安装。

---

# ⚙️ 三、CUDA 工具链管理

### 🚀 安装 CUDA 12.8

```Bash
dpkg -i cuda-repo-ubuntu2204-12-8-local_12.8.0-570.86.10-1_amd64.deb
apt-get update
apt install cuda-toolkit-12-8
```

**作用：**

- 添加 CUDA 本地仓库。
- 安装 CUDA 编译器 (`nvcc`) 和库 (`libcudart`, `cublas` 等)。
---

### 🧩 验证 CUDA 是否可用

```Bash
cd /usr/local/cuda/samples/1_Utilities/deviceQuery
make
./deviceQuery
```

**作用：**

编译并运行官方示例 `deviceQuery`，验证 GPU 计算功能是否可用。

---

# 🐳 四、Docker GPU 环境配置

### 🧰 安装 NVIDIA Container Toolkit

```Bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
apt-get update
apt install -y nvidia-container-toolkit
```

**作用：**

为 Docker/Containerd 添加 NVIDIA GPU 支持，使容器可以访问 GPU。

---

### 🧩 配置 Docker Runtime

```Bash
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
```

**作用：**

配置 Docker 使用 `nvidia` 运行时。

之后运行容器时加上 `--gpus all` 即可使用 GPU。

---

### 🧹 卸载 Docker

```Bash
apt purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**作用：**

清理 Docker，以便迁移到 containerd。

---

# ⚙️ 五、Containerd + K8s GPU 支持配置

### 🧩 配置 Containerd 运行时

```Bash
nvidia-ctk runtime configure --runtime=containerd
systemctl restart containerd
```

**作用：**

修改 `/etc/containerd/config.toml`，注册 `nvidia` 运行时。

K8s 的 kubelet 就能调用 GPU。

---

### 🔍 验证配置

```Bash
grep -A3 "\[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.nvidia" /etc/containerd/config.toml
crictl ps
systemctl status containerd
```

**作用：**

查看 containerd 的 GPU 配置是否生效、运行状态是否正常。

---

### 🔧 Kubelet 调整

```Bash
cat /var/lib/kubelet/kubeadm-flags.env | grep container-runtime
systemctl restart kubelet
```

**作用：**

检查 kubelet 是否使用 containerd，并重新加载。

---

# ☁️ 六、K8s GPU Operator 调试

```Bash
kubectl get pods -n gpu-operator
kubectl describe pod nvidia-cuda-validator-xxx -n gpu-operator
```

**作用：**

查看 GPU Operator 部署状态。

`cuda-validator` 用于验证 GPU 驱动与容器运行时的可用性。

---

# 🌐 七、网络与 CNI 清理

```Bash
ip link delete cni0
ip link delete flannel.1
rm -rf /var/lib/cni/*
rm -f /etc/cni/net.d/*
```

**作用：**

删除旧的 CNI 网络设备与配置（比如 Flannel/Multus），

解决 “network plugin not initialized” 等 kubelet 错误。

---

# 🧱 八、系统与基础命令

```Bash
df -hT       # 查看磁盘分区及类型
mount -a     # 挂载 /etc/fstab 中定义的所有文件系统
systemctl isolate multi-user.target  # 切换到纯命令行模式（无图形）
hostnamectl set-hostname NVIDIA-A100-01
htop         # 交互式系统资源监视器
```

**作用：**

系统维护、调试环境、性能监控。

---

# 🎯 九、学习重点建议

为了从“知道命令”到“真正理解”，可以按以下路线学习：

| 模块 | 学习重点 | 推荐实践 |
| --- | --- | --- |
| NVIDIA 驱动 | `nvidia-smi`、`rmmod`、`.run` 安装原理 | 手动卸载/重装驱动一次 |
| CUDA 工具链 | `nvcc`、`deviceQuery` | 编译 CUDA 示例 |
| Docker GPU 支持 | `nvidia-container-toolkit` | 启动一个 GPU 容器跑 `nvidia-smi` |
| Containerd GPU 支持 | 配置 `/etc/containerd/config.toml` | 在 K8s Pod 中跑 GPU workload |
| K8s GPU Operator | 理解 DaemonSet + Validator 原理 | 查看 Operator 生成的资源结构 |
| CNI 网络 | `cni0`、`flannel.1` 的作用 | 手动重置网络、验证恢复 |

---
