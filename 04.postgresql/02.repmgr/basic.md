1. 环境规划

- repmgr（监控复制过程、自动故障切换）
- witness（防止脑裂）
- keepalived（监控主库状态，自动切换VIP）

主库：10.0.0.61  + pg15.5 + postgis3.3 + repmgr5.4.1 [master]

备库：10.0.0.62  + pg15.5 + postgis3.3 + repmgr5.4.1 [slave]

仲裁：10.0.0.63  + pg15.5 + repmgr5.4.1 [witness]


2. 安装 repmgr

61 主节点执行

```shell
bash install-pg-15.5-x86.sh
source /etc/profile
bash install-postgis-3.3-x86.sh
bash install-repmgr-master-x86.sh 10.0.0.61 1 primary
```
62 备节点执行

```shell
bash install-pg-15.5-x86.sh
source /etc/profile
bash install-postgis-3.3-x86.sh
bash install-repmgr-slave-prepare-x86.sh 10.0.0.62 2
```

61 62 都执行

```shell
su postgres
cat > ~/.pgpass << EOF
10.0.0.61:5432:repmgr:repmgr:123456
10.0.0.62:5432:repmgr:repmgr:123456
EOF
chmod 600 ~/.pgpass
exit
```

62 备节点执行

```shell
# 从 61 节点克隆数据
sudo -iu postgres repmgr -h 10.0.0.61 -U repmgr -d repmgr -f /data/repmgr/etc/repmgr.conf standby clone --dry-run
sudo -iu postgres repmgr -h 10.0.0.61 -U repmgr -d repmgr -f /data/repmgr/etc/repmgr.conf standby clone
# 123456 是 repmgr.conf 中的 password

# 注册为备库
systemctl start postgresql5432
sudo -iu postgres repmgr -f /data/repmgr/etc/repmgr.conf standby register --upstream-node-id=1
sudo -iu postgres repmgr -f /data/repmgr/etc/repmgr.conf cluster show
```

3. 安装 witness

63 节点执行

```shell
bash install-pg-15.5-x86.sh
source /etc/profile
bash install-repmgr-witness-prepare-x86.sh 10.0.0.63 3

su postgres
echo "10.0.0.61:5432:repmgr:repmgr:123456" >> ~/.pgpass
echo "10.0.0.62:5432:repmgr:repmgr:123456" >> ~/.pgpass
echo "10.0.0.63:5432:repmgr:repmgr:123456" >> ~/.pgpass
chmod 600 ~/.pgpass
cat ~/.pgpass
exit
```

61 62执行

```shell
su postgres
echo "10.0.0.63:5432:repmgr:repmgr:123456" >> ~/.pgpass
cat ~/.pgpass
exit
```

63 节点执行

```shell
# 注册节点
sudo -iu postgres repmgr -f /data/repmgr/etc/repmgr.conf -h 10.0.0.61 -U repmgr -d repmgr witness register
sudo -iu postgres repmgr -f /data/repmgr/etc/repmgr.conf -U repmgr -d repmgr cluster show

# 查看节点信息
psql -d repmgr -c "select * from repmgr.nodes;"
```

62 节点切换为主，61 节点切换为备

```shell
# 62 节点执行
sudo -iu postgres repmgr -f /data/repmgr/etc/repmgr.conf standby switchover --dry-run --force

sudo -iu postgres repmgr -f /data/repmgr/etc/repmgr.conf standby switchover --force
# 备库确实可以拉起为主库，但是旧主库无法指向新主库

# 提前配一下三台机器的 ssh，postgres用户的免密

# systemd
```

