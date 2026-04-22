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

# 2. get the architecture of the system
arch=$(uname -m)
print_colored "$BLUE" "System architecture: $arch"


# 3. download and install PostgreSQL 15.5 RPM packages
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

if [[ -f postgresql15-contrib-15.5-1PGDG.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "PostgreSQL 15.5 contrib RPM package already downloaded"
else
    print_colored "$YELLOW" "Downloading PostgreSQL 15.5 contrib RPM package..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/postgresql15-contrib-15.5-1PGDG.rhel7.x86_64.rpm
fi

yum -y install libzstd
yum -y install libicu
rpm -ivh postgresql15-libs-15.5-1PGDG.rhel7.x86_64.rpm
rpm -ivh postgresql15-15.5-1PGDG.rhel7.x86_64.rpm
rpm -ivh postgresql15-server-15.5-1PGDG.rhel7.x86_64.rpm


# 4. create user and set password for postgres
useradd -r -s /sbin/nologin postgres

# 5. create directories for data, log, run, backup and archive, because etc file in data directory, so we don't create it separately.
mkdir -pv /data/5432/{archive,backup,data,log,run}

# 6. set up symbolic links and permissions
ln -s /usr/pgsql-15 /usr/local/pgsql
chown -R postgres.postgres /usr/local/pgsql/
chown -R postgres.postgres /data/5432
chmod 700 /data/5432

# 7. set environment variables for postgres user
cat >> /etc/profile << 'EOF'
export PGHOME=/usr/local/pgsql
export PGHOST=/data/5432/run
export PGPORT=5432
export PGDATA=/data/5432/data
export PGUSER=postgres
export PATH=$PGHOME/bin:$PATH
EOF
source /etc/profile

# 8. initialize the database cluster
su -s /bin/bash postgres -c "initdb -D /data/5432/data -U postgres -E UTF8 --locale=zh_CN.UTF-8"

# 9. please mannualy edit the postgresql.conf and pg_hba.conf files to set the appropriate configurations for your environment
# such as listen_addresses, port, authentication methods, etc.
cp -a /data/5432/data/pg_hba.conf /data/5432/data/pg_hba.conf.bak
cp -a /data/5432/data/postgresql.conf /data/5432/data/postgresql.conf.bak

# 10. perf ormance tuning for postgresql.conf, you can adjust the values based on your system resources and workload requirements

# shared_buffers should be set to 25% of total system memory
total_memory=$(free -g | awk '/^Mem:/{print $2}')
calculated_shared_buffers=$(( (total_memory + 3) / 4 ))
# set shared_buffers to the calculated value, but not less than 1GB
if [[ $calculated_shared_buffers -lt 1 ]]; then
    shared_buffers=1
else
    shared_buffers=$calculated_shared_buffers
fi

echo "Calculated shared_buffers: ${shared_buffers}GB"

cat >> /data/5432/data/postgresql.conf << EOF
external_pid_file = '/data/5432/run/postmaster.pid'
listen_addresses= '*'
port = 5432
max_connections = 500
unix_socket_directories = '/data/5432/run'
shared_buffers = ${shared_buffers}GB 
logging_collector=on
log_directory='/data/5432/log'
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
archive_command = 'test ! -f /data/5432/archive/%f && cp %p /data/5432/archive/%f'
EOF

# 11. set up systemd service for PostgreSQL
cp -a /usr/lib/systemd/system/postgresql-15.service /usr/lib/systemd/system/postgresql.service
sed -i 's#Environment=PGDATA=/var/lib/pgsql/15/data/#Environment=PGDATA=/data/5432/data/#g' /usr/lib/systemd/system/postgresql.service
sed -i 's#ExecStartPre=/usr/pgsql-15/#ExecStartPre=/usr/local/pgsql/#g' /usr/lib/systemd/system/postgresql.service
sed -i 's#ExecStart=/usr/pgsql-15/#ExecStart=/usr/local/pgsql/#g' /usr/lib/systemd/system/postgresql.service
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