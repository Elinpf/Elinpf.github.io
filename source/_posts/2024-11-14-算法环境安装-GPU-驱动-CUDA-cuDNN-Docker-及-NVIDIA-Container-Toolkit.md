---
title: 算法环境安装 GPU 驱动、CUDA、cuDNN、Docker 及 NVIDIA Container Toolkit
date: 2024-11-14 11:23:18
tags:
- gpu
- cuda
- docker
categories:
- 运维
---

## 环境要求

- 内核版本 > 3.10 的 GNU/Linux x86_64
- Docker >=19.03（支持最低的版本为1.12）
- 架构 >= Kepler（或计算能力 3.0）的 NVIDIA GPU
- [NVIDIA Linux 驱动程序](http://www.nvidia.com/object/unix.html) >= 418.81.07

### 下载驱动

下载对应型号[GPU驱动](https://www.nvidia.cn/drivers/lookup/)安装，例如A10。

### 安装步骤

```Bash
# 查看显卡是否正常识别
lspci | grep NVIDIA

# 禁用nouveau并重启
cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF

# CentOS
sudo dracut --force
reboot

# Ubuntu
sudo update-initramfs -u
sudo reboot

# 验证禁用成功（无输出表示成功）
lsmod |grep nouveau

# CentOS安装基础依赖环境
yum -y install gcc kernel-devel kernel-headers

# Ubuntu安装gcc和make
apt-get -y install gcc make

# 安装GPU驱动
cd /opt
# https://www.nvidia.com/Download/driverResults.aspx/224350/en-us/
chmod +x NVIDIA-Linux-x86_64-515.105.01.run
sh NVIDIA-Linux-x86_64-515.105.01.run -no-x-check -no-nouveau-check -no-opengl-files

# 验证安装
nvidia-smi
```

### 安装选项

安装过程中选择：

1. `Would you like to register the kernel module sources with DKMS?` → **NO**
2. `Install 32-bit compatibility libraries?` → **N**
3. `Would you like to run the nvidia-xconfig utility...` → **NO**
其他选择默认选项。

### 常见错误解决

```Bash
# 安装对应内核版本的头文件
yum install kernel-devel-$(uname -r) kernel-headers-$(uname -r)

# 指定内核源文件路径安装
sudo ./NVIDIA-Linux-x86_64-515.105.01.run --no-opengl-files --kernel-source-path=/usr/src/kernels/3.10.0-1127.13.1.el7.x86_64/

# 重新生成initramfs
mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak
dracut /boot/initramfs-$(uname -r).img $(uname -r)

# 错误：GPU不支持警告
sh NVIDIA-Linux-x86_64-515.105.01.run -no-opengl-files -no-nouveau-check –add-this-kernel

# 卸载Ubuntu自带驱动后重装
apt-get purge nvidia*

# 关闭系统自动更新
sed -i.bak 's/1/0/' /etc/apt/apt.conf.d/10periodic
sed -i.bak 's/1/0/' /etc/apt/apt.conf.d/20auto-upgrades
systemctl stop unattended-upgrades
systemctl disable unattended-upgrades
```

### GPU驱动降级

```Bash
# 卸载原显卡驱动
nvidia-uninstall

# 备份并重建initramfs
mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak
dracut /boot/initramfs-$(uname -r).img $(uname -r)

# 下载并安装新版本驱动
wget https://us.download.nvidia.cn/tesla/535.54.03/NVIDIA-Linux-x86_64-535.54.03.run
chmod +x NVIDIA-Linux-x86_64-535.54.03.run 
./NVIDIA-Linux-x86_64-535.54.03.run -no-x-check -no-nouveau-check -no-opengl-files

# 查看并卸载模块
lsmod | grep nvidia
rmmod nvidia_uvm
modprobe -r nvidia-drm

# 结束占用进程
lsof /dev/nvidia*
kill -9 <进程ID>
```

### 安装CUDA

```Bash
# 下载CUDA（版本关系参考：https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html）
cd /opt
wget https://developer.download.nvidia.com/compute/cuda/12.2.0/local_installers/cuda_12.2.0_535.54.03_linux.run
chmod +x cuda_12.2.0_535.54.03_linux.run 
sudo sh cuda_12.2.0_535.54.03_linux.run
```

安装选项：

- 取消选择driver [x表示选择]
- 安装完成后验证：`nvcc -V`
环境变量配置：

```Bash
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64' >> ~/.bashrc
echo 'export CUDA_HOME=/usr/local/cuda' >> ~/.bashrc
source ~/.bashrc
```

### 安装cuDNN

```Bash
# https://developer.nvidia.com/cudnn-downloads?target_os=Linux&target_arch=x86_64
tar -zxvf cudnn-10.1-linux-x64-v7.6.3.30.tgz

# 复制文件到CUDA目录
cp cuda/include/cudnn*.h /usr/local/cuda/include 
cp -P cuda/lib64/libcudnn* /usr/local/cuda/lib64 
chmod a+r /usr/local/cuda/include/cudnn*.h /usr/local/cuda/lib64/libcudnn*

# 生效配置
ldconfig
```

### Ubuntu安装

参考：[Docker官方文档](https://docs.docker.com/engine/install/ubuntu/)

### CentOS安装  

参考：[Docker官方文档](https://docs.docker.com/engine/install/centos/)

### 离线安装

```Bash
wget -O docker_tool.zip "https://ostor.sensoro.com/sensoro-backup/docker_tool.zip"
unzip docker_tool.zip && cd docker_tool
sh -x install.sh docker-24.0.5.tgz
```

### Ubuntu系统

```Bash
# 配置APT源
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://mirrors.ustc.edu.cn/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://nvidia.github.io#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://mirrors.ustc.edu.cn#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 安装
apt update && sudo apt install nvidia-container-toolkit -y

# 配置Docker
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
```

### CentOS系统

```Bash
# 配置Docker CE源
yum-config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
# 或使用阿里源
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 安装containerd.io和docker-ce
yum install docker-ce -y
systemctl --now enable docker

# 安装NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
yum-config-manager --enable libnvidia-container-experimental
yum clean expire-cache
yum install -y nvidia-container-toolkit

# 配置Docker
nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 验证安装

```Bash
docker run --rm --runtime=nvidia --gpus all harbor.sensoro.com/library/nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi
```

### 常见错误解决

```Bash
# 开启GPU持久模式
nvidia-smi -pm 1

# 开机自启动
echo 'nvidia-smi -pm 1' >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local

# 在/etc/docker/daemon.json添加
"default-runtime": "nvidia",
```

### 1. 检查NVIDIA驱动是否安装

```Bash
# 查看系统推荐的驱动版本
ubuntu-drivers devices

# 检查已安装的驱动
dpkg -l | grep -i nvidia
```

### 2. 安装NVIDIA驱动

```Bash
sudo apt update
sudo apt install nvidia-driver-535
# 或自动安装推荐版本
sudo ubuntu-drivers autoinstall
sudo reboot
```

### 3. 重新加载内核模块

```Bash
sudo rmmod nvidia
sudo modprobe nvidia
lsmod | grep nvidia
```

### 4. 处理Secure Boot冲突

```Bash
# 查看Secure Boot状态
mokutil --sb-state
```

如果启用Secure Boot：

- **方法1**：进入BIOS/UEFI设置关闭Secure Boot
- **方法2**：安装驱动时生成签名密钥
### 5. 修复驱动与内核版本冲突

```Bash
sudo apt install --reinstall nvidia-driver-535
sudo update-initramfs -u
sudo reboot
```

### 6. 完全卸载并重装驱动

```Bash
sudo apt purge nvidia-*
sudo apt autoremove
sudo rm -rf /usr/lib/nvidia
sudo rm -rf /etc/X11/xorg.conf
sudo apt install nvidia-driver-535
sudo update-initramfs -u
sudo reboot
```

### 7. 检查硬件和日志

```Bash
dmesg | grep -i nvidia
nvidia-bug-report.sh
```

## 私有化离线环境

对于私有化离线环境安装NVIDIA Container Toolkit，请参考相关内部文档。

---

**注意**：所有操作前请确保备份重要数据，并在测试环境中验证后再应用到生产环境。

### 使用CUDA版本管理器

```Bash
# 安装cuda版本管理工具
wget https://raw.githubusercontent.com/rmarquis/cudam/master/cudam
chmod +x cudam
sudo mv cudam /usr/local/bin/

# 查看已安装的CUDA版本
cudam list

# 切换CUDA版本
cudam switch 11.8
cudam switch 12.2
```

### 手动管理多版本CUDA

```Bash
# 安装多个CUDA版本到不同目录
sudo sh cuda_11.8.0_520.61.05_linux.run --installpath=/usr/local/cuda-11.8
sudo sh cuda_12.2.0_535.54.03_linux.run --installpath=/usr/local/cuda-12.2

# 创建符号链接切换版本
sudo rm -f /usr/local/cuda
sudo ln -s /usr/local/cuda-12.2 /usr/local/cuda

# 验证当前版本
nvcc --version
```

### 环境变量配置

```Bash
# 在~/.bashrc中添加CUDA版本切换函数
cuda_switch() {
    local version=$1
    local cuda_path="/usr/local/cuda-$version"
    
    if [ -d "$cuda_path" ]; then
        sudo rm -f /usr/local/cuda
        sudo ln -s "$cuda_path" /usr/local/cuda
        echo "Switched to CUDA $version"
    else
        echo "CUDA $version not found"
    fi
}

# cuda_switch 12.2
```

### Docker Compose GPU支持

```YAML
version: '3.8'

services:
  gpu-app:
    image: nvidia/cuda:11.8-runtime-ubuntu20.04
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    volumes:
      - ./app:/app
    working_dir: /app
    command: python train.py

  specific-gpu:
    image: nvidia/cuda:11.8-runtime-ubuntu20.04
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=0,1  # 指定使用GPU 0和1
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['0', '1']
              capabilities: [gpu]
```

### 容器运行时配置检查

```Bash
# 检查容器运行时配置
docker info | grep -i runtime

# 验证nvidia-container-runtime
which nvidia-container-runtime

# 检查Docker守护进程配置
cat /etc/docker/daemon.json

# 期望输出包含：
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "default-runtime": "nvidia"
}
```

### 实时监控工具

```Bash
# 基础监控
nvidia-smi
watch -n 1 nvidia-smi  # 每秒刷新

# 更详细的监控
nvidia-smi --query-gpu=timestamp,name,pci.bus_id,driver_version,pstate,pcie.link.gen.max,pcie.link.gen.current,temperature.gpu,utilization.gpu,utilization.memory,memory.total,memory.free,memory.used --format=csv -l 1

# 使用gpustat工具
pip install gpustat
gpustat -i 1
```

### GPU进程管理

```Bash
# 查看GPU进程
nvidia-smi pmon -c 1

# 杀死占用GPU的进程
sudo fuser -v /dev/nvidia*

# 根据进程名查找GPU进程
ps aux | grep python | grep -v grep
nvidia-smi | grep -A 10 Processes
```

### GPU健康检查脚本

```Bash
#!/bin/bash
# gpu-health-check.sh

echo "=== GPU Health Check ==="

# 检查驱动状态
echo "1. Checking NVIDIA driver..."
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=driver_version --format=csv,noheader
else
    echo "NVIDIA driver not found!"
    exit 1
fi

# 检查GPU数量
echo -e "\n2. Checking GPU count..."
GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
echo "Found $GPU_COUNT GPU(s)"

# 检查GPU温度
echo -e "\n3. Checking GPU temperature..."
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | while read temp; do
    if [ $temp -gt 85 ]; then
        echo "WARNING: High GPU temperature: ${temp}°C"
    else
        echo "Normal temperature: ${temp}°C"
    fi
done

# 检查显存使用
echo -e "\n4. Checking memory usage..."
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader | while read line; do
    echo "Memory: $line"
done

# 检查持久模式
echo -e "\n5. Checking persistence mode..."
PERSISTENCE=$(nvidia-smi -q | grep "Persistence Mode" | awk '{print $4}')
echo "Persistence Mode: $PERSISTENCE"

echo -e "\n=== Health Check Complete ==="
```

### GPU功率限制设置

```Bash
# 查看当前功率限制
nvidia-smi -q -d POWER

# 设置功率限制（以A10为例，150W为最大值）
sudo nvidia-smi -i 0 -pl 120  # 设置GPU 0为120W
sudo nvidia-smi -i 1 -pl 120  # 设置GPU 1为120W

# 永久设置功率限制（添加到启动脚本）
echo '#!/bin/bash
nvidia-smi -i 0 -pl 120
nvidia-smi -i 1 -pl 120' | sudo tee /etc/rc.local
```

### GPU时钟频率设置

```Bash
# 查看支持的时钟频率
nvidia-smi -q -d SUPPORTED_CLOCKS

# 设置持久时钟频率
sudo nvidia-smi -lgc 1000,1000  # 设置图形和内存时钟

# 重置为默认值
sudo nvidia-smi -rgc
```

### MIG（Multi-Instance GPU）配置

```Bash
# 检查MIG支持
nvidia-smi -i 0 -q | grep MIG

# 启用MIG模式
sudo nvidia-smi -i 0 -mig 1

# 创建GPU实例
sudo nvidia-smi mig -i 0 -cgi 1g.5gb,1g.5gb

# 查看MIG实例
nvidia-smi -L
```

### 系统日志分析

```Bash
# 查看内核日志中的NVIDIA相关消息
dmesg | grep -i nvidia

# 查看系统日志
journalctl -u nvidia-persistenced
journalctl -u docker | grep -i gpu

# 检查Xorg日志（如果有图形界面）
cat /var/log/Xorg.0.log | grep -i nvidia
```

### 驱动兼容性检查

```Bash
#!/bin/bash
# check-compatibility.sh

echo "=== NVIDIA Driver Compatibility Check ==="

# 检查内核版本
echo "Kernel version: $(uname -r)"

# 检查GCC版本
echo "GCC version: $(gcc --version | head -1)"

# 检查驱动版本
if command -v nvidia-smi &> /dev/null; then
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    echo "NVIDIA Driver version: $DRIVER_VERSION"
else
    echo "NVIDIA Driver: Not installed"
fi

# 检查CUDA版本
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}')
    echo "CUDA version: $CUDA_VERSION"
else
    echo "CUDA: Not installed"
fi

# 检查NVIDIA Container Toolkit
if command -v nvidia-ctk &> /dev/null; then
    echo "NVIDIA Container Toolkit: Installed"
else
    echo "NVIDIA Container Toolkit: Not installed"
fi
```

### 容器GPU访问问题诊断

```Bash
# 测试基础GPU访问
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi

# 测试特定GPU
docker run --rm --gpus '"device=0"' nvidia/cuda:11.0-base nvidia-smi

# 检查容器内GPU设备
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base ls -la /dev/ | grep nvidia

# 验证CUDA运行时
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvcc --version
```

### 完整的GPU环境安装脚本

```Bash
#!/bin/bash
# install-gpu-environment.sh

set -e

echo "Starting GPU environment installation..."

# 检测操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS $VERSION"

# 禁用nouveau
disable_nouveau() {
    echo "Disabling nouveau driver..."
    cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF
    
    if [ "$OS" = "ubuntu" ]; then
        update-initramfs -u
    elif [ "$OS" = "centos" ]; then
        dracut --force
    fi
}

# 安装依赖
install_dependencies() {
    echo "Installing dependencies..."
    if [ "$OS" = "ubuntu" ]; then
        apt-get update
        apt-get install -y gcc make linux-headers-$(uname -r)
    elif [ "$OS" = "centos" ]; then
        yum install -y gcc kernel-devel-$(uname -r) kernel-headers-$(uname -r)
    fi
}

# 安装NVIDIA驱动
install_nvidia_driver() {
    local driver_version=${1:-"535.54.03"}
    echo "Installing NVIDIA driver $driver_version..."
    
    # 下载驱动（这里需要根据实际情况调整URL）
    wget -O /tmp/nvidia-driver.run "https://us.download.nvidia.cn/tesla/${driver_version}/NVIDIA-Linux-x86_64-${driver_version}.run"
    chmod +x /tmp/nvidia-driver.run
    /tmp/nvidia-driver.run -s --no-opengl-files
}

# 安装CUDA
install_cuda() {
    local cuda_version=${1:-"12.2"}
    echo "Installing CUDA $cuda_version..."
    
    # 下载CUDA（需要根据版本调整URL）
    wget -O /tmp/cuda.run "https://developer.download.nvidia.com/compute/cuda/${cuda_version}.0/local_installers/cuda_${cuda_version}.0_535.54.03_linux.run"
    chmod +x /tmp/cuda.run
    /tmp/cuda.run --silent --toolkit --override
}

# 安装Docker
install_docker() {
    echo "Installing Docker..."
    if [ "$OS" = "ubuntu" ]; then
        apt-get install -y docker.io
    elif [ "$OS" = "centos" ]; then
        yum install -y docker
    fi
    
    systemctl enable docker
    systemctl start docker
}

# 安装NVIDIA Container Toolkit
install_nvidia_container_toolkit() {
    echo "Installing NVIDIA Container Toolkit..."
    
    if [ "$OS" = "ubuntu" ]; then
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        apt-get update
        apt-get install -y nvidia-container-toolkit
    elif [ "$OS" = "centos" ]; then
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
        yum install -y nvidia-container-toolkit
    fi
    
    # 配置Docker
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
}

# 主安装流程
main() {
    disable_nouveau
    install_dependencies
    install_nvidia_driver
    install_cuda
    install_docker
    install_nvidia_container_toolkit
    
    echo "Installation completed! Please reboot the system."
    echo "After reboot, verify with: nvidia-smi && docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi"
}

main "$@"
```

### 1. 版本兼容性

- 始终检查[NVIDIA官方兼容性矩阵](https://docs.nvidia.com/deploy/cuda-compatibility/)
- 保持驱动、CUDA、容器工具包版本一致
- 在生产环境部署前进行充分测试
### 2. 性能优化

- 根据工作负载调整GPU功率限制
- 使用持久模式避免GPU休眠
- 合理设置容器GPU资源限制
### 3. 监控和维护

- 定期检查GPU温度和健康状况
- 监控显存使用情况，避免OOM
- 保持驱动和软件更新到稳定版本
### 4. 安全考虑

- 在容器中合理限制GPU访问权限
- 避免在容器中以root身份运行GPU应用
- 定期检查安全更新和漏洞
这个完整的指南涵盖了从基础安装到高级配置的所有方面，应该能够帮助您成功部署和维护NVIDIA GPU环境。
