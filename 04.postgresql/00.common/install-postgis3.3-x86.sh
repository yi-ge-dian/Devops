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

# todo：验证是否一定需要做
# yum install -y epel-release

# 配置 PostgreSQL 15 源
cat > /etc/yum.repos.d/pgdg-custom.repo << EOF
[pgdg-common]
name=PostgreSQL common RPMs for RHEL/CentOS 7 - x86_64
baseurl=https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-7-x86_64
enabled=1
gpgcheck=0

[pgdg15]
name=PostgreSQL 15 for RHEL/CentOS 7 - x86_64
baseurl=https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64
enabled=1
gpgcheck=0
EOF

# todo：验证是否一定需要做
# yum clean all && yum makecache 

# 安装包
cd /usr/local/pg15.5-rpm
if [[ -f postgresql15-contrib-15.5-1PGDG.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "PostgreSQL 15.5 contrib RPM package already downloaded"
else
    print_colored "$YELLOW" "Downloading PostgreSQL 15.5 contrib RPM package..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/postgresql15-contrib-15.5-1PGDG.rhel7.x86_64.rpm
fi


# todo 验证是否一定需要做
# yum install -y python3
rpm -ivh postgresql15-contrib-15.5-1PGDG.rhel7.x86_64.rpm

# 安装 PostGIS 3.3
yum install -y postgis33_15

# 检查 postgis 扩展是否已启用
if psql -c "SELECT PostGIS_Version();" | grep -q "3.3"; then
    print_colored "$GREEN" "[Success] PostGIS 3.3 installed successfully"
else
    print_colored "$RED" "[Error] PostGIS 3.3 installation failed"
fi