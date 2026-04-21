#!/bin/bash

# Color definitions
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

Redis_version="7.4.8"
Port="6379"

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

# 2. get the machine architecture
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    print_colored "$GREEN" "[Success] Machine architecture: x86_64"
elif [[ "$arch" == "aarch64" ]]; then
    print_colored "$GREEN" "[Success] Machine architecture: aarch64"
else
    print_colored "$RED" "[Error] Unsupported machine architecture: $arch"
    exit 1
fi

# 3. perf the redis system
cat > /etc/sysctl.conf << EOF
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 4096
vm.overcommit_memory = 1
EOF
sysctl -p
print_colored "$GREEN" "[Success] Redis perf configured"


# 4. set transparent_hugepage
# right now
echo never > /sys/kernel/mm/transparent_hugepage/enabled
# forever
echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
print_colored "$GREEN" "[Success] Transparent_hugepage set"


# 5. wget the redis tar, check if the file exists and is valid 
cd /usr/local/
if [[ -f "redis-${Redis_version}.tar.gz" ]]; then
    print_colored "$GREEN" "[Success] Redis tar already exists"
else
    print_colored "$BLUE" "[Info] Downloading Redis v${Redis_version}"
    wget https://download.redis.io/releases/redis-${Redis_version}.tar.gz
fi

# 6. install redis
tar -xvf redis-${Redis_version}.tar.gz
ln -s redis-${Redis_version} redis
cd /usr/local/redis
make -j "$(nproc)" USE_SYSTEMD=yes && make install
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to install Redis"
    exit 1
fi
print_colored "$GREEN" "[Success] Redis installed"

# 7. redis version
cd /usr/local/
redis-server -v

# 8. congfiue path redis
cat >> /etc/profile << EOF
export PATH=/usr/local/redis/bin:$PATH
EOF
source /etc/profile

# 9. configure redis
mkdir -pv /data/$Port/{data,etc,log,run,backup}
useradd -r -s /sbin/nologin redis
chown -R redis.redis /data/$Port/
chmod -R 700 /data/$Port

cp /usr/local/redis/redis.conf /data/$Port/etc/redis.conf
cat >> /data/$Port/etc/redis.conf << EOF
####################################### basic configuration
bind 0.0.0.0
port  $Port
unixsocket /data/$Port/run/redis.sock
supervised systemd
dir /data/$Port/data
pidfile /data/$Port/run/redis.pid
logfile "/data/$Port/log/redis.log"
####################################### connection configuration
maxclients 10000
requirepass 123456
maxmemory 1024MB
######################################## persistence configuration
appendonly yes
appendfilename "appendonly-$Port.aof"
appendfsync everysec
no-appendfsync-on-rewrite yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 1024MB
####################################### safe configuration
rename-command CONFIG ""
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command SHUTDOWN ""
rename-command KEYS ""
####################################### master-slave configuration
masterauth 123456
min-slaves-to-write 0
min-slaves-max-lag 15
EOF
print_colored "$GREEN" "[Success] Redis conf configured"

# 10. configure redis systemd service
cat > /usr/lib/systemd/system/redis.service<< EOF
[Unit]
Description=Redis Server
After=network.target

[Service]
ExecStart=/usr/local/bin/redis-server /data/$Port/etc/redis.conf
Type=notify
User=redis
Group=redis
LimitNOFILE=65535
LimitNPROC=65535
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
print_colored "$GREEN" "[Success] Redis systemd service configured"

# 11. start redis
systemctl daemon-reload
systemctl start redis
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to start Redis service"
    exit 1
fi
systemctl enable redis
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to enable Redis service"
    exit 1
fi
print_colored "$GREEN" "[Success] Redis service started and enabled on boot"

# 12. check redis status
systemctl status redis