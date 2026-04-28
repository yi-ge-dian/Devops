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

Port="3306"

# 检查是否含有 mariaDB
rpm -qa | grep mariadb
if [[ $? -eq 0 ]]; then
    print_colored "$YELLOW" "[Warning] MariaDB is installed, uninstalling..."
    yum remove -y mariadb*
fi

# 二进制安装
cd /usr/local
if [[ -f mysql-8.0.45-linux-glibc2.17-x86_64.tar.xz ]]; then
    print_colored "$GREEN" "[Success] MySQL is downloaded!"
else
    print_colored "$GREEN" "[Success] Downloading MySQL..."
    wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.45-linux-glibc2.17-$arch.tar.xz
    print_colored "$GREEN" "[Success] Downloading completed!"
fi

# 解压
tar xvf mysql-8.0.45-linux-glibc2.17-$arch.tar.xz
ln -s mysql-8.0.40-linux-glibc2.17-aarch64 mysql

# 配置环境变量
cat >> /etc/profile << EOF
export PATH=/usr/local/mysql/bin:$PATH
EOF
source /etc/profile
mysql -V

# 创建数据目录
useradd -r -s /sbin/nologin mysql
mkdir -pv /data/$Port/{data,log,run,etc,backup}
touch /data/$Port/etc/my.cnf
chown -R mysql.mysql /data/$Port/
chown -R mysql.mysql /usr/local/mysql/
chmod 700 /data/$Port

# 初始化数据库
mysqld --initialize-insecure --user=mysql --basedir=/usr/local/mysql --datadir=/data/$Port/data

# 配置服务
cat > /data/$Port/etc/my.cnf << EOF
[mysql]
port = $Port
socket = /data/$Port/run/mysql.sock
default-character-set = utf8mb4

[mysqld]
########################################################################################## basic
port = $Port
bind-address = 0.0.0.0
basedir = /usr/local/mysql
datadir = /data/$Port/data
pid-file = /data/$Port/run/mysqld.pid
socket = /data/$Port/run/mysql.sock

########################################################################################## user
user=mysql

########################################################################################## connections
max_connections = 500

########################################################################################## character-set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

########################################################################################## log
general_log = off
general_log_file=/data/$Port/log/general.log
log_error=/data/$Port/log/error.log
log_bin=/data/$Port/log/binlog
binlog_format=row
slow_query_log = 0
slow_query_log_file = /data/$Port/log/slow.log
long_query_time = 5
log_queries_not_using_indexes = 1

########################################################################################## security
activate_all_roles_on_login = on

########################################################################################## gtid
gtid_mode = on   
enforce_gtid_consistency = on
EOF

# 启动服务
cat >/usr/lib/systemd/system/mysqld$Port.service<<EOF
[Unit]
Description=MySQL Server
Documentation=man:mysqld(8)
After=network.target
After=syslog.target

[Install]
WantedBy=multi-user.target

[Service]
User=mysql
Group=mysql
LimitNOFILE=65535
LimitNPROC=65535
ExecStart=/usr/local/mysql/bin/mysqld --defaults-file=/data/$Port/etc/my.cnf
EOF

systemctl daemon-reload
systemctl start mysqld$Port
if [[ $? -eq 0 ]]; then
    print_colored "$GREEN" "[Success] MySQL is running!"
else
    print_colored "$RED" "[Error] MySQL running error!"
    exit 1
fi

systemctl enable mysqld$Port
if [[ $? -eq 0 ]]; then
    print_colored "$GREEN" "[Success] MySQL is enabled!"
else
    print_colored "$RED" "[Error] MySQL enable error!"
    exit 1
fi
systemctl status mysqld$Port
mysql -e "select version();"

mysqladmin -uroot password '123456'