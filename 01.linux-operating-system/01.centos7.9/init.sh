#!/bin/bash

# 色卡
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# 颜色打印函数
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# 校验是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   print_colored "$RED" "[Error] This script must be run as root"
   exit 1
fi

# 获得 CPU 架构
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    print_colored "$GREEN" "[Success] Machine architecture: x86_64"
elif [[ "$arch" == "aarch64" ]]; then
    print_colored "$GREEN" "[Success] Machine architecture: aarch64"
else
    print_colored "$RED" "[Error] Unsupported machine architecture: $arch"
    exit 1
fi

# 检查 SELinux 状态，如果为 enforcing，则禁用 SELinux
selinux_status=$(getenforce)
if [[ "$selinux_status" == "Enforcing" ]]; then
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    print_colored "$GREEN" "[Success] SELinux disabled"
else
    print_colored "$GREEN" "[Success] SELinux is already disabled"
fi

# 检查防火墙状态，如果为 active，则禁用防火墙
firewall_status=$(systemctl is-active firewalld)
if [[ "$firewall_status" == "active" ]]; then
    systemctl disable firewalld --now 
    print_colored "$GREEN" "[Success] Firewall disabled"
else
    print_colored "$GREEN" "[Success] Firewall is already disabled"
fi

# 更新软件源
bak_dir="/etc/yum.repos.d/bak_$(date +%Y%m%d_%H%M%S)"
mkdir "$bak_dir"
mv /etc/yum.repos.d/*.repo "$bak_dir"
curl -s -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
curl -s -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo
yum clean all
yum makecache fast
print_colored "$GREEN" "[Success] Software sources updated"

# 安装必要的工具
yum install -y vim wget net-tools lsof iotop chrony unzip tree gcc systemd-devel make
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to install necessary tools"
    exit 1
fi
print_colored "$GREEN" "[Success] Necessary packages installed"

# 设置时区为上海
timedatectl set-timezone Asia/Shanghai

# 同步时间
cat  > /etc/chrony.conf << EOF
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst
server ntp4.aliyun.com iburst

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
#allow 192.168.0.0/16

# Serve time even if not synchronized to a time source.
#local stratum 10

# Specify file containing keys for NTP authentication.
#keyfile /etc/chrony.keys

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
EOF

# 启动 chrony 服务
systemctl enable chronyd --now
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to start chrony service and enable on boot"
    exit 1
fi
timedatectl
print_colored "$GREEN" "[Success] Time synchronized with chrony service In Public NTP Servers"
print_colored "$YELLOW" "[Warning] Please manually edit the chrony service In Private NTP Servers, restart the chrony service and manually synchronize the clock time using 'hwclock --systohc'"

# 同步硬件时钟
hwclock --systohc
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to sync hardware clock with system time"
    exit 1
fi