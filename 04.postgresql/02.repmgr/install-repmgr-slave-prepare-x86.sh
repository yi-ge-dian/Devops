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

# 使用说明：
# ./install-repmgr-slave-x86.sh <host_ip> <node_id> 
# host_ip: 主机IP地址
# node_id: 节点ID
# ./install-repmgr-slave-x86.sh 10.0.0.62 2

host_ip=$1
node_id=$2
host_port=5432

# host_ip 需要作为传入的参数，如果不传入报错
if [ -z "$host_ip" ]; then
    print_colored "$RED" "[Error] host_ip is required"
    exit 1
fi
host_ip=$1

# node_id 需要作为传入的参数，如果不传入报错
if [ -z "$node_id" ]; then
    print_colored "$RED" "[Error] node_id is required"
    exit 1
fi
node_id=$2

# 下载 repmgr rpm 包
# repmgr_15-5.3.3-1.rhel7.x86_64.rpm                 02-Jan-2024 18:05              284208
# repmgr_15-5.4.0-1.rhel7.x86_64.rpm                 02-Jan-2024 18:05              287604
# repmgr_15-5.4.1-1PGDG.rhel7.x86_64.rpm             02-Jan-2024 18:05              287784
# repmgr_15-devel-5.3.3-1.rhel7.x86_64.rpm           02-Jan-2024 18:05                8844
# repmgr_15-devel-5.4.0-1.rhel7.x86_64.rpm           02-Jan-2024 18:05                9332
# repmgr_15-devel-5.4.1-1PGDG.rhel7.x86_64.rpm       02-Jan-2024 18:05                9608
# repmgr_15-llvmjit-5.3.3-1.rhel7.x86_64.rpm         02-Jan-2024 18:05               21736
# repmgr_15-llvmjit-5.4.0-1.rhel7.x86_64.rpm         02-Jan-2024 18:05               22220
# repmgr_15-llvmjit-5.4.1-1PGDG.rhel7.x86_64.rpm     02-Jan-2024 18:05               22496
mkdir -p /usr/local/repmgr5.4.1-rpm
cd /usr/local/repmgr5.4.1-rpm
if [[ -f repmgr-5.5.0-1.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "Repmgr 5.5.0 RPM package already downloaded"
else
    print_colored "$YELLOW" "Downloading Repmgr 5.5.0 RPM package..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/repmgr_15-5.4.1-1PGDG.rhel7.x86_64.rpm
fi

rpm -ivh repmgr_15-5.4.1-1PGDG.rhel7.x86_64.rpm
source /etc/profile

# 创建 repmgr 配置文件目录
mkdir -p /data/repmgr/etc
cat > /data/repmgr/etc/repmgr.conf << EOF
node_id = $node_id
node_name = node_$node_id
conninfo = 'host=$host_ip port=$host_port user=repmgr password=123456 dbname=repmgr connect_timeout=2'
data_directory = '/data/$host_port/data'
pg_bindir = '/usr/local/pgsql/bin'
EOF
chown -R postgres:postgres /data/repmgr
chmod 700 /data/repmgr

# 备份从节点自己之前的数据文件
systemctl stop postgresql$host_port
# 更稳健的备份脚本
backup_dir="/data/$host_port/backup"
backup_name="data_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
data_dir="/data/$host_port/data"

# 确保备份目录存在
mkdir -p "$backup_dir"

# 创建备份（排除临时文件和日志）
tar -zcvf "$backup_dir/$backup_name" \
    --exclude='postmaster.pid' \
    -C "$data_dir" .

if [ $? -eq 0 ]; then
    print_colored "$GREEN" "备份成功，备份文件位于 $backup_dir/$backup_name"
    # 清理旧备份（可选：保留最近7天）
    find "$backup_dir" -name "data_backup_*.tar.gz" -mtime +7 -delete
else
    print_colored "$RED" "备份失败"
    exit 1
fi