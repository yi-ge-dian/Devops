# 1. 主从配置

执行 install-master.sh 创建主节点
执行 install-slave.sh 创建从节点

1. 连接
```bash
redis-cli -h 10.0.0.181 -p 6379 -c123456 info
# 主节点
redis-cli -h 10.0.0.181 -p 6379 -a123456 set k1 v1
redis-cli -h 10.0.0.181 -p 6379 -a123456 get k1
# 从节点
redis-cli -h 10.0.0.182 -p 6379 -a123456 get k1
```

# 2. 注意事项

1. 主从节点的密码要一致
2. 主节点可以写入、从节点只能读
