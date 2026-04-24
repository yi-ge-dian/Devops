1. 哨兵架构

10.0.0.181 26379

10.0.0.182 26379

10.0.0.183 26379

2. 一主两从安装完成后，三个节点配置哨兵

```
# sentinel monitor <master-name> <ip> <redis_port> <quorum>
# master-name：哨兵监控的主节点名称
# ip：主节点地址
# redis-port：主节点端口

```shell
redis_master=10.0.0.181
redis_port=6379
sentinel_port=26379
manager_cluster_name=my-sentinel-master

# 创建目录
mkdir -p /data/${sentinel_port}/{etc,log,data,run}
chown -R redis.redis /data/${sentinel_port}/
chmod 700 /data/${sentinel_port}/

# 配置文件
cp -a /usr/local/redis/sentinel.conf /data/${sentinel_port}/etc/sentinel.conf
cat > /data/${sentinel_port}/etc/sentinel.conf << EOF
####################################### basic configuration
bind 0.0.0.0
port  ${sentinel_port}
unixsocket /data/${sentinel_port}/run/sentinel.sock
dir /data/${sentinel_port}/data
pidfile /data/${sentinel_port}/run/sentinel.pid
logfile "/data/${sentinel_port}/log/sentinel.log"
protected-mode no
daemonize yes
####################################### sentinel configuration
sentinel monitor $manager_cluster_name ${redis_master} ${redis_port} 2
sentinel down-after-milliseconds $manager_cluster_name 10000
sentinel parallel-syncs $manager_cluster_name 2
sentinel failover-timeout $manager_cluster_name 15000
sentinel auth-pass $manager_cluster_name 123456
EOF

# 启动哨兵
/usr/local/bin/redis-sentinel /data/${sentinel_port}/etc/sentinel.conf
netstat -tnulp |grep 26379
```

3. 查看哨兵状态

```
redis-cli -h 10.0.0.181 -p 26379 info sentinel
```

4. 进入181，停止主节点

```
systemctl stop redis6379
```

5. 查看哨兵状态

```
redis-cli -h 10.0.0.181 -p 26379 info sentinel
```

6. 查看后台日志

```
tail -f /data/26379/log/sentinel.log
```

7. 查看节点状态

```
redis-cli -h 10.0.0.182 -p 6379 -a 123456 info replication
redis-cli -h 10.0.0.183 -p 6379 -a 123456 info replication
```

9. 恢复主节点

```
systemctl start redis6379
```

10. 查看节点状态

```
redis-cli -h 10.0.0.181 -p 6379 -a 123456 info replication
```