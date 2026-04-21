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


# 3. mkdir sentinel
mkdir -p /data/26379/{etc,log,data,run}
chmod -R 700 /data/26379/
chown -R redis.redis /data/26379/

# 4. configure sentinel
cp -a /usr/local/redis/sentinel.conf /data/26379/etc/sentinel.conf
cat > /data/26379/etc/sentinel.conf << EOF
####################################### basic configuration
bind 0.0.0.0
port  26379
unixsocket /data/26379/run/sentinel.sock
dir /data/26379/data
pidfile /data/26379/run/sentinel.pid
logfile "/data/26379/log/sentinel.log"
protected-mode no
daemonize yes
####################################### sentinel configuration
sentinel monitor my—sentinel-master 10.0.0.181 6379 2
sentinel down-after-milliseconds my—sentinel-master 10000
sentinel parallel-syncs my—sentinel-master 2
sentinel failover-timeout my—sentinel-master 15000
sentinel auth-pass my—sentinel-master 123456
EOF

# 5. start sentinel
/usr/local/bin/redis-sentinel /data/26379/etc/sentinel.conf
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to start Redis Sentinel"
    exit 1
fi
print_colored "$GREEN" "[Success] Redis Sentinel started"