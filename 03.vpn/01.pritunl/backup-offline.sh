#!/bin/bash

# Color definitions
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

SCP_MANCHINE_IP="xxx.xxx.xxx.xxx"

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

# 2. check the scp machine ip is valid
if ! ping -c 1 -W 1 "$SCP_MANCHINE_IP" &>/dev/null; then
    print_colored "$RED" "[Error] IP $SCP_MANCHINE_IP is not reachable"
    exit 1
fi

# 2. create backup directory
back_dir="backup-$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p /data/pritunl/$back_dir

# 3. do backup
cp -a /data/pritunl/pritunl /data/pritunl/$back_dir
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to copy pritunl directory"
    exit 1
fi
cp -a /data/pritunl/mongodb /data/pritunl/$back_dir
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to copy mongodb directory"
    exit 1
fi
print_colored "$GREEN" "[Success] Backup copied to /data/pritunl/$back_dir"

# 4. compress 
cd /data/pritunl
tar -zcf $back_dir.tar.gz -C /data/pritunl/$back_dir/ .
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to compress backup"
    exit 1
fi
print_colored "$GREEN" "[Success] Backup compressed to $back_dir.tar.gz"

# 5. send to remote machine
scp $back_dir.tar.gz root@$SCP_MANCHINE_IP:/data/pritunl/backup/
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to send backup to remote machine"
    exit 1
fi

