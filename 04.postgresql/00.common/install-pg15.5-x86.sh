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

Port="5432"

# 下载 PostgreSQL 15.5 RPM 包
mkdir /usr/local/pg15.5-rpm && cd /usr/local/pg15.5-rpm
if [[ -f postgresql15-libs-15.5-1PGDG.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "PostgreSQL 15.5 RPM packages already downloaded"
else
    print_colored "$YELLOW" "Downloading PostgreSQL 15.5 RPM packages..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/postgresql15-libs-15.5-1PGDG.rhel7.x86_64.rpm 
fi

if [[ -f postgresql15-15.5-1PGDG.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "PostgreSQL 15.5 server RPM package already downloaded"
else
    print_colored "$YELLOW" "Downloading PostgreSQL 15.5 server RPM package..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/postgresql15-15.5-1PGDG.rhel7.x86_64.rpm 
fi

if [[ -f postgresql15-server-15.5-1PGDG.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "PostgreSQL 15.5 server RPM package already downloaded"
else
    print_colored "$YELLOW" "Downloading PostgreSQL 15.5 server RPM package..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/postgresql15-server-15.5-1PGDG.rhel7.x86_64.rpm 
fi

yum -y install libzstd
yum -y install libicu
rpm -ivh postgresql15-libs-15.5-1PGDG.rhel7.x86_64.rpm
rpm -ivh postgresql15-15.5-1PGDG.rhel7.x86_64.rpm
rpm -ivh postgresql15-server-15.5-1PGDG.rhel7.x86_64.rpm


# 创建 PostgreSQL 用户
useradd -r -s /sbin/nologin postgres

# 创建目录，配置文件存在于 data 目录下，所以不需要单独创建 etc 目录
mkdir -pv /data/$Port/{archive,backup,data,log,run}

# 创建软链接，方便使用
ln -s /usr/pgsql-15 /usr/local/pgsql
chown -R postgres.postgres /usr/local/pgsql/
chown -R postgres.postgres /data/$Port
chmod 700 /data/$Port

# 设置环境变量
cat >> /etc/profile << 'EOF'
export PGHOME=/usr/local/pgsql
export PGHOST=/data/$Port/run
export PGPORT=$Port
export PGDATA=/data/$Port/data
export PGUSER=postgres
export PATH=$PGHOME/bin:$PATH
EOF
source /etc/profile

# 初始化数据库
su -s /bin/bash postgres -c "initdb -D /data/$Port/data -U postgres -E UTF8 --locale=zh_CN.UTF-8"

# 请手动编辑 postgresql.conf 和 pg_hba.conf 文件，以设置适合您环境的适当配置
cp -a /data/$Port/data/pg_hba.conf /data/$Port/data/pg_hba.conf.bak
cp -a /data/$Port/data/postgresql.conf /data/$Port/data/postgresql.conf.bak

# 通过 postgresql.conf 文件，可以调整 PostgreSQL 的性能，以适应您的系统资源和工作负载要求

# 1. shared_buffers should be set to 25% of total system memory
total_memory=$(free -g | awk '/^Mem:/{print $2}')
calculated_shared_buffers=$(( (total_memory + 3) / 4 ))
# set shared_buffers to the calculated value, but not less than 1GB
if [[ $calculated_shared_buffers -lt 1 ]]; then
    shared_buffers=1
else
    shared_buffers=$calculated_shared_buffers
fi

echo "Calculated shared_buffers: ${shared_buffers}GB"

cat >> /data/$Port/data/postgresql.conf << EOF
external_pid_file = '/data/$Port/run/postmaster.pid'
listen_addresses= '*'
port = $Port
max_connections = 500
unix_socket_directories = '/data/$Port/run'
shared_buffers = ${shared_buffers}GB 
logging_collector=on
log_directory='/data/$Port/log'
log_filename = 'postgresql-%a.log'
log_rotation_age = 1d
log_rotation_size = 1GB
log_truncate_on_rotation = on
log_min_duration_statement = 5000
idle_in_transaction_session_timeout = 1000000
idle_session_timeout = 300000
wal_level = replica
max_wal_senders = 10
wal_sender_timeout = 60s
archive_mode = on
archive_command = 'test ! -f /data/$Port/archive/%f && cp %p /data/$Port/archive/%f'
EOF

# 系统服务启动
cp -a /usr/lib/systemd/system/postgresql-15.service /usr/lib/systemd/system/postgresql$Port.service
sed -i 's#Environment=PGDATA=/var/lib/pgsql/15/data/#Environment=PGDATA=/data/$Port/data/#g' /usr/lib/systemd/system/postgresql$Port.service
sed -i 's#ExecStartPre=/usr/pgsql-15/#ExecStartPre=/usr/local/pgsql/#g' /usr/lib/systemd/system/postgresql$Port.service
sed -i 's#ExecStart=/usr/pgsql-15/#ExecStart=/usr/local/pgsql/#g' /usr/lib/systemd/system/postgresql$Port.service
systemctl daemon-reload
systemctl enable postgresql --now
if systemctl is-active --quiet postgresql; then
    print_colored "$GREEN" "PostgreSQL service started successfully"
    systemctl status postgresql --no-pager
else
    print_colored "$RED" "Failed to start PostgreSQL service"
    exit 1
fi

# e.g.create user
# 创建 my_user 用户，并设置密码为 123456，user 默认具有登录权限
# CREATE USER my_user WITH PASSWORD '123456';

# 创建 my_role 角色，并设置密码为 123456，role 默认不具有登录权限,如果想要登录权限，请使用 WITH LOGIN
# CREATE ROLE my_role WITH LOGIN PASSWORD '123456';

# 创建 my_database 数据库，所有者为 my_user 用户
# CREATE DATABASE my_database OWNER my_user;

# 创建 my_database 数据库，所有者为 my_role 角色
# CREATE DATABASE my_database OWNER my_role;

# 删除 my_database 数据库
# DROP DATABASE my_database;

# 删除 my_user 用户
# DROP USER my_user;