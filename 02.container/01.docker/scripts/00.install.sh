#!/bin/bash

# Color definitions
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

docker_version="26.1.4"
docker_compose_version="2.27.1"

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

# 3. wget the docker tar, check if the file exists and is valid
docker_tar="docker-${docker_version}.tgz"
if [[ -f "$docker_tar" ]]; then
    print_colored "$GREEN" "[Success] Docker tar already exists"
else
    print_colored "$BLUE" "[Info] Downloading Docker v${docker_version}"
    wget "https://download.docker.com/linux/static/stable/${arch}/${docker_tar}"
    if [[ $? -ne 0 ]]; then
        print_colored "$RED" "[Error] Failed to download Docker tar"
        exit 1
    fi
    print_colored "$GREEN" "[Success] Docker tar downloaded"
fi

# 4. extract the docker tar and move the binaries to /usr/local/bin
tar -xvf "$docker_tar"
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to extract Docker tar"
    exit 1
fi
cp -a docker/* /usr/local/bin/
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to move Docker binaries"
    exit 1
fi
print_colored "$GREEN" "[Success] Docker binaries moved to /usr/local/bin"

# 5. configure the docker systemd service
cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/local/bin/dockerd -H unix:///var/run/docker.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
# Older systemd versions default to a LimitNOFILE of 1024:1024, which is insufficient for many
# applications including dockerd itself and will be inherited. Raise the hard limit, while
# preserving the soft limit for select(2).
LimitNOFILE=65535:524288

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

[Install]
WantedBy=multi-user.target
EOF

chmod +x /usr/lib/systemd/system/docker.service

mkdir -p /etc/docker/
mkdir -p /data/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors":[
    "https://docker.1panel.live",
    "https://docker.m.daocloud.io",
    "https://docker.rainbond.cc"
  ],
  "data-root": "/data/docker",
  "log-driver": "json-file",
  "log-opts": {
      "max-size": "100m",
      "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"],
  "storage-driver": "overlay2",
  "live-restore": true,
  "experimental": false
}
EOF
print_colored "$GREEN" "[Success] Docker systemd service configured"

# 6. start the docker service and enable it to start on boot
systemctl daemon-reload
systemctl start docker
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to start Docker service"
    exit 1
fi
systemctl enable docker
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to enable Docker service"
    exit 1
fi
print_colored "$GREEN" "[Success] Docker service started and enabled on boot"

# 7. check the docker version
docker version


# 8. install docker-compose
docker_compose_file="docker-compose-linux-${arch}"
if [[ -f "$docker_compose_file" ]]; then
    print_colored "$GREEN" "[Success] Docker Compose file already exists"
else
    print_colored "$BLUE" "[Info] Downloading Docker Compose v${docker_compose_version}"
    wget "https://github.com/docker/compose/releases/download/v${docker_compose_version}/${docker_compose_file}"
    if [[ $? -ne 0 ]]; then
        print_colored "$RED" "[Error] Failed to download Docker Compose"
        exit 1
    fi
    print_colored "$GREEN" "[Success] Docker Compose file downloaded"
fi

cp -a "$docker_compose_file" "/usr/local/bin/docker-compose"
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to copy Docker Compose"
    exit 1
fi

if ! chmod +x "/usr/local/bin/docker-compose"; then
    print_colored "$RED" "[Error] Failed to set executable permissions for Docker Compose"
    rm -f "/usr/local/bin/docker-compose"
    exit 1
fi

print_colored "$GREEN" "[Success] Docker Compose v${docker_compose_version} installed"
docker-compose version