1. 集群架构

主：10.0.0.181 6379

主：10.0.0.182 6379

主：10.0.0.183 6379

从：10.0.0.184 6379

从：10.0.0.185 6379

从：10.0.0.186 6379

2. 六台节点全部安装 install-master.sh, 增加一些配置
```shell
cat >> /data/6379/etc/redis.conf << EOF
masterauth 123456
cluster-enabled yes
cluster-node-timeout 15000
cluster-slave-validity-factor 10
cluster-require-full-coverage no
EOF

systemctl restart redis6379
```
3. 查看集群状态
```shell
redis-cli -h 10.0.0.181 -p 6379 -a 123456 cluster info
redis-cli -h 10.0.0.181 -p 6379 -a 123456 cluster nodes
```


3. 创建集群
```shell
# 注意断开连接工具的广播模式，一个节点做就可以
redis-cli -h 10.0.0.181 -a 123456 --cluster create --cluster-replicas 1 10.0.0.181:6379 10.0.0.182:6379 10.0.0.183:6379 10.0.0.184:6379 10.0.0.185:6379 10.0.0.186:6379
```

4. 查看集群状态
```shell
redis-cli -h 10.0.0.181 -p 6379 -a 123456 cluster info
redis-cli -h 10.0.0.181 -p 6379 -a 123456 cluster nodes
```

5. 使用集群
```shell
# 注意断开连接工具的广播模式，一个节点做就可以
redis-cli -h 10.0.0.181 -p 6379 -a 123456 -c set name zhangsan
redis-cli -h 10.0.0.181 -p 6379 -a 123456 -c get name
```

6. 检查集群状态
```shell
redis-cli -h 10.0.0.181 -p 6379 -a 123456 --cluster check 10.0.0.181:6379
```