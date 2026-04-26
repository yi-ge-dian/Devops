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
















yum -y install libpython3.6m.so.1.0
rpm -ivh postgresql15-contrib-15.5-1PGDG.rhel7.x86_64.rpm