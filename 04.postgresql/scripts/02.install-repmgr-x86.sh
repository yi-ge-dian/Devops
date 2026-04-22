#!/bin/bash

# Color definitions
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color


# 使用说明：
# ./install-repmgr-x86.sh <host_ip> <node_id> <register_status>
# host_ip: 主机IP地址
# node_id: 节点ID
# register_status: 注册状态
# ./install-repmgr-x86.sh 10.0.0.61 1 primary
# ./install-repmgr-x86.sh 10.0.0.62 2 standby

# 0. Function to print colored messages
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

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

# register_status 需要作为传入的参数，如果不传入报错
if [ -z "$register_status" ]; then
    print_colored "$RED" "[Error] register_status is required"
    exit 1
fi
register_status=$3

# 1. check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   print_colored "$RED" "[Error] This script must be run as root"
   exit 1
fi

# 2. get the architecture of the system
arch=$(uname -m)
print_colored "$BLUE" "System architecture: $arch"


# 3. download and install repgmr RPM packages
# repmgr_15-5.3.3-1.rhel7.x86_64.rpm                 02-Jan-2024 18:05              284208
# repmgr_15-5.4.0-1.rhel7.x86_64.rpm                 02-Jan-2024 18:05              287604
# repmgr_15-5.4.1-1PGDG.rhel7.x86_64.rpm             02-Jan-2024 18:05              287784
# repmgr_15-devel-5.3.3-1.rhel7.x86_64.rpm           02-Jan-2024 18:05                8844
# repmgr_15-devel-5.4.0-1.rhel7.x86_64.rpm           02-Jan-2024 18:05                9332
# repmgr_15-devel-5.4.1-1PGDG.rhel7.x86_64.rpm       02-Jan-2024 18:05                9608
# repmgr_15-llvmjit-5.3.3-1.rhel7.x86_64.rpm         02-Jan-2024 18:05               21736
# repmgr_15-llvmjit-5.4.0-1.rhel7.x86_64.rpm         02-Jan-2024 18:05               22220
# repmgr_15-llvmjit-5.4.1-1PGDG.rhel7.x86_64.rpm     02-Jan-2024 18:05               22496
mkdir -p /usr/local/repmgr5.4.1-rpm && cd /usr/local/repmgr5.4.1-rpm
if [[ -f repmgr-5.5.0-1.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "Repmgr 5.5.0 RPM package already downloaded"
else
    print_colored "$YELLOW" "Downloading Repmgr 5.5.0 RPM package..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/repmgr_15-5.4.1-1PGDG.rhel7.x86_64.rpm
fi

rpm -ivh repmgr-5.5.0-1.rhel7.x86_64.rpm
source /etc/profile

# 4. create user and set password for repmgr
psql -U postgres -c "CREATE USER repmgr WITH SUPERUSER LOGIN PASSWORD '123456';"
# 5. create database for repmgr
psql -U postgres -c "CREATE DATABASE repmgr OWNER repmgr;"
# 6. create schema for repmgr
psql -U postgres -c "ALTER USER repmgr SET search_path TO repmgr, public;"

# 5. add pg_hba.conf entry
cat >> /data/5432/data/pg_hba.conf << EOF
local repmgr repmgr md5
host repmgr repmgr 127.0.0.1/32 md5
host repmgr repmgr 0.0.0.0/24 md5

local replication repmgr md5
host replication repmgr 127.0.0.1/32 md5
host replication repmgr 0.0.0.0/24 md5
EOF

# 6. reload postgresql
su -s /bin/bash postgres -c "pg_ctl reload"

# 7. modify repmgr.conf
mkdir -p /data/repmgr/etc

cat > /data/repmgr/etc/repmgr.conf << EOF
node_id = $node_id
node_name = node_$node_id
conninfo = 'host=$host_ip port=5432 user=repmgr password=123456 dbname=repmgr connect_timeout=2'
data_directory = '/data/5432/data'
pg_bindir = '/usr/local/pgsql/bin'
EOF
chown -R postgres:postgres /data/repmgr

# 8. register node
su -s /bin/bash postgres -c "repmgr -f /data/repmgr/etc/repmgr.conf $register_status register"
su -s /bin/bash postgres -c "repmgr -f /data/repmgr/etc/repmgr.conf cluster show"

# 9. psql -U repmgr
# > select * from repmgr.nodes;