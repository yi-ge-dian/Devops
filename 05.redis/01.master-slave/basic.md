# 1. 主从配置

执行 install-master.sh ，然后加入一些配置创建主节点
```shell
Port=6379
cat >> /data/$Port/etc/redis.conf << EOF
####################################### master-slave configuration
masterauth 123456
min-slaves-to-write 0
min-slaves-max-lag 15
EOF

systemctl restart redis$Port
```

执行 install-master.sh ，然后加入一些配置创建从节点
```shell
Port=6379
Master_IP=10.0.0.181
Master_Port=6379
cat >> /data/$Port/etc/redis.conf << EOF
####################################### master-slave configuration
masterauth 123456
min-slaves-to-write 0
min-slaves-max-lag 15
slaveof $Master_IP $Master_Port
slave-read-only yes
EOF

systemctl restart redis$Port
```

连接
```bash
# 主节点
redis-cli -h 10.0.0.181 -p 6379 -a 123456 info
redis-cli -h 10.0.0.181 -p 6379 -a 123456 set k1 v1
redis-cli -h 10.0.0.181 -p 6379 -a 123456 get k1
# 从节点
redis-cli -h 10.0.0.182 -p 6379 -a 123456 get k1
redis-cli -h 10.0.0.182 -p 6379 -a 123456 set k2 v2
# 主节点
redis-cli -h 10.0.0.181 -p 6379 -a 123456 del k1
```

# 2. 注意事项

1. 主从节点的密码要一致
2. 主节点可以写入、从节点只能读
