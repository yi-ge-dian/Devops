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


# 2. check selinux and disable if necessary
selinux_status=$(getenforce)
if [[ "$selinux_status" == "Enforcing" ]]; then
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    print_colored "$GREEN" "[Success] SELinux disabled"
else
    print_colored "$GREEN" "[Success] SELinux is already disabled"
fi


# 3. check firewall and disable if necessary
firewall_status=$(systemctl is-active firewalld)
if [[ "$firewall_status" == "active" ]]; then
    systemctl disable firewalld --now 
    print_colored "$GREEN" "[Success] Firewall disabled"
else
    print_colored "$GREEN" "[Success] Firewall is already disabled"
fi


# 4. update the software sources
cd /etc/yum.repos.d
bak_dir="bak_$RANDOM"
mkdir "$bak_dir"
mv *.repo "$bak_dir"
curl -s -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
curl -s -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo
yum clean all
yum makecache fast
print_colored "$GREEN" "[Success] Software sources updated"

# 5. install necessary tools
yum install -y vim wget net-tools lsof iotop chrony unzip tree gcc systemd-devel
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to install necessary tools"
    exit 1
fi
print_colored "$GREEN" "[Success] Necessary packages installed"

# 6. set zone and sync time
timedatectl set-timezone Asia/Shanghai

cat <<EOF > /etc/chrony.conf
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst
server ntp4.aliyun.com iburst

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
#allow 192.168.0.0/16

# Serve time even if not synchronized to a time source.
#local stratum 10

# Specify file containing keys for NTP authentication.
#keyfile /etc/chrony.keys

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
EOF

systemctl enable chronyd --now
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to start chrony service"
    exit 1
fi
timedatectl

print_colored "$GREEN" "[Success] Time synchronized with chrony service In Public NTP Servers"
print_colored "$YELLOW" "[Warning] Please manually edit the chrony service In Private NTP Servers"

# 7. sync hardware clock with system time
hwclock --systohc
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to sync hardware clock with system time"
    exit 1
fi