1. 添加节点

主：10.0.0.187 6379

主：10.0.0.188 6379

从：10.0.0.189 6379 --> 187

从：10.0.0.190 6379 --> 188


2. 四台节点全部安装 install-master.sh, 增加一些配置
```shell
cat >> /data/6379/data/redis.conf << EOF
cluster enabled yes
cluster-node-timeout 15000
cluster-slave-validity-factor 10
cluster-require-ful l-coverage no
EOF

systemctl restart redis
```

3. 增加节点进入集群
```shell
# meet
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster meet 10.0.0.187 6379
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster meet 10.0.0.188 6379
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster meet 10.0.0.189 6379
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster meet 10.0.0.190 6379
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster info
# 进入从节点 189
redis-cli -h 10.0.0.189 -p 6379 -a123456
> cluster replicate 9d5b9a8e9f5c9e6d7e8f9a0b1c2d3e4f5(187_node_id)
# 进入从节点 190
redis-cli -h 10.0.0.190 -p 6379 -a123456
> cluster replicate 8d7f6e5d4c3b2a1f0e9a8b7c6d5e4f3(188_node_id)
> cluster info
> cluster saveconfig
# check
redis-cli -h 10.0.0.187 -p 6379 -a123456 -c cluster check
```

4. 删除节点
```shell
# 10.0.0.181
redis-cli -h 10.0.0.181 -p 6379 -a123456
# 确保主从节点没有槽位了，先将从节点从集群中移除，再移除主节点
> cluster forget 9d5b9a8e9f5c9e6d7e8f9a0b1c2d3e4f5(189_node_id)
> cluster forget 8d7f6e5d4c3b2a1f0e9a8b7c6d5e4f3(190_node_id)
> cluster forget 7d6f5e4d3c2b1a0f9e8d7c6b5a4(188_node_id)
> cluster forget 6d5e4f3a2b1c3d4e5f6a7b8c9d0e1(187_node_id)
> cluster saveconfig

# 另外一种方式，推荐使用该方案
# 确保主从节点没有槽位了，先将从节点从集群中移除，再移除主节点
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c del-node 6d5e4f3a2b1c3d4e5f6a7b8c9d0e1(187_node_id)
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c del-node 7d6f5e4d3c2b1a0f9e8d7c6b5a4(188_node_id)
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c del-node 9d5b9a8e9f5c9e6d7e8f9a0b1c2d3e4f5(189_node_id)
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c del-node 8d7f6e5d4c3b2a1f0e9a8b7c6d5e4f3(190_node_id)
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster saveconfig

# 被删除的节点停止服务，删除文件
systemctl stop redis # 10.0.0.187
rm -rf /data/6379/data/*
rm -rf /data/6379/etc/redis.conf
```