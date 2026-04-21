#!/bin/bash

# Color definitions
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# 0. Function to print colored messages
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# 1. check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   print_colored "$RED" "[Error] This script must be run as root"
   exit 1
fi

# 2. optimize system settings
BACKUP_FILE="/etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)"
cp -a /etc/sysctl.conf "$BACKUP_FILE"

################################################################  Memory Optimization ################################################################
# 减少系统使用交换分区的倾向
echo "vm.swappiness = 5" >> /etc/sysctl.conf
# 设置系统内存中脏页的最大比例和最小比例，优化磁盘写入性能
echo "vm.dirty_ratio = 5" >> /etc/sysctl.conf           
echo "vm.dirty_background_ratio = 2" >> /etc/sysctl.conf

################################################################ Network Optimization ################################################################
# 优化TCP连接的参数，增加系统处理大量并发连接的能力
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
# 增加TCP连接的backlog队列长度，提升系统处理大量连接请求的能力
echo "net.ipv4.tcp_max_syn_backlog = 819200" >> /etc/sysctl.conf
# 增加网络接口的接收队列长度，提升系统处理大量网络流量的能力
echo "net.core.netdev_max_backlog = 400000" >> /etc/sysctl.conf
# 增加TCP连接的keepalive时间，提升系统处理长时间连接的能力
echo "net.core.somaxconn = 4096" >> /etc/sysctl.conf
# 优化TCP连接的TIME_WAIT状态，允许重用TIME_WAIT状态的连接，提升系统处理大量短连接的能力
echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
# 禁止TCP连接的TIME_WAIT状态被快速回收，避免出现连接重用导致的问题
echo "net.ipv4.tcp_tw_recycle = 0" >> /etc/sysctl.conf


sysctl -p
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to optimize system settings"
    exit 1
else
    print_colored "$GREEN" "[Success] System settings optimized, backup created at $BACKUP_FILE"
fi

