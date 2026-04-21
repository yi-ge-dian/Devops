#!/bin/bash

# Color definitions
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# Remember to unzip after uploading
pritunl_tar_path="/root/dongwenlong/pritunl.tar"

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

# 2. load the docker images tar
docker load -i $pritunl_tar_path
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to load Docker images from pritunl tar"
    exit 1
fi

mkdir -p /data/pritunl
cat > /data/pritunl/docker-compose.yaml << EOF
version: '3.3'
services:
    pritunl:
        container_name: pritunl
        image: jippi/pritunl:1.32.3697.80 
        restart: unless-stopped
        privileged: true
        ports:
            - '8443:443'
            - '1195:1195'
            - '1195:1195/udp'
            - '1196:1196'
            - '1196:1196/udp'
        dns:
            - 127.0.0.1
        volumes:
            - '/data/pritunl/pritunl:/var/lib/pritunl'
            - '/data/pritunl/mongodb:/var/lib/mongodb'
EOF

print_colored "$GREEN" "[Success] Docker images loaded and docker-compose.yaml created"

# 3. start the pritunl container
cd /data/pritunl
docker-compose up -d
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to start the pritunl container"
    exit 1
fi
print_colored "$GREEN" "[Success] Pritunl container started"

# 4. print the pritunl default password
docker exec pritunl pritunl default-password
if [[ $? -ne 0 ]]; then
    print_colored "$RED" "[Error] Failed to get the pritunl default password"
    exit 1
fi

# Administrator default password:
# username: "pritunl"
# password: "5cqIOh6QIipo"