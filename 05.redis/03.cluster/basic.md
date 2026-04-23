1. 集群架构

主：10.0.0.181 6379

主：10.0.0.182 6379

主：10.0.0.183 6379

从：10.0.0.184 6379 --> 181

从：10.0.0.185 6379 --> 182

从：10.0.0.186 6379 --> 183

2. 六台节点全部安装 install-master.sh, 增加一些配置
```shell
cat >> /data/6379/data/redis.conf << EOF
cluster enabled yes
cluster-node-timeout 15000
cluster-slave-validity-factor 10
cluster-require-ful l-coverage no
EOF

systemctl restart redis
```
3. 查看集群状态
```shell
redis-cli -h 10.0.0.181 -p 6379 -a123456 --cluster info
redis-cli -h 10.0.0.181 -p 6379 -a123456 --cluster nodes
redis-cli -h 10.0.0.182 -p 6379 -a123456 --cluster info
redis-cli -h 10.0.0.182 -p 6379 -a123456 --cluster nodes
redis-cli -h 10.0.0.183 -p 6379 -a123456 --cluster info
redis-cli -h 10.0.0.183 -p 6379 -a123456 --cluster nodes
redis-cli -h 10.0.0.184 -p 6379 -a123456 --cluster info
redis-cli -h 10.0.0.184 -p 6379 -a123456 --cluster nodes
redis-cli -h 10.0.0.185 -p 6379 -a123456 --cluster info
redis-cli -h 10.0.0.185 -p 6379 -a123456 --cluster nodes
redis-cli -h 10.0.0.186 -p 6379 -a123456 --cluster info
redis-cli -h 10.0.0.186 -p 6379 -a123456 --cluster nodes
```


3. 创建集群
```shell
redis-cli -h 10.0.0.181 -p 6379 -a123456 --cluster create 10.0.0.181:6379 10.0.0.182:6379 10.0.0.183:6379 10.0.0.184:6379 10.0.0.185:6379 10.0.0.186:6379 --cluster-replicas 1
```

4. 集群方式连接
```shell
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c set k2 v2
```

5. 查看集群状态
```shell
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster nodes
redis-cli -h 10.0.0.181 -p 6379 -a123456 -c cluster info
```