# 1. 主从搭建

主：10.0.0.61

备：10.0.0.62

1. 主从先跑一遍 install-pg15.5 脚本
2. 主库 61 创建用户
```shell
psql -U postgres -c "CREATE ROLE repl_user WITH LOGIN PASSWORD '123456' REPLICATION;"
```

3. 主库 61 修改 pg_hba.conf
```shell
cat > /data/5432/data/pg_hba.conf << EOF
host all all 0.0.0.0/0 md5
host replication repl_user 0.0.0.0/0 md5
EOF
```

## 1.1. 删除从库的数据目录

```shell
# 从库执行
systemctl stop postgresql
cd /data/5432/backup
tar -zcvf data_backup_$(date +%Y%m%d%H%M%S).tar.gz -C /data/5432/data .
rm -rf /data/5432/data/*
```

## 1.2. 从库拉取主库数据

```shell
# 确保主库 61 启动
systemctl status postgresql

# 从库执行
# -F p : 以纯格式进行备份，生成一个包含 SQL 语句的文本文件
# -P : 显示备份进度
# -R : 在备份完成后自动生成 standby.conf 标识文件，同时把 recovery (pg11) 配置从库连接的参数转移到 postgresql.conf 文件中了
# -l : backup20260419 : 备份文件的标签，便于识别和管理
cd /data/5432
su -s /bin/bash postgres -c "pg_basebackup -h 10.0.0.61 -p 5432 -U repl_user -D /data/5432/data -F p -P -R -l backup20260419"

# 查看会产生一个标识文件：standby.signal
ll /data/5432/data/standby.signal
# 增加连接信息
echo "primary_conninfo = 'host=10.0.0.61 port=5432 user=repl_user password=123456'" >> /data/5432/data/postgresql.conf
# 从库启动
systemctl start postgresql
```

## 1.3. 查看主从复制状态
```shell
# 主库执行
psql -U postgres -x -c "SELECT * FROM pg_stat_replication;"
# 从库执行
psql -U postgres -c "SELECT pg_is_in_recovery();"
```

## 1.4. 主从复制验证
```shell
# 主库执行
CREATE TABLE test_sync (id INT, info TEXT);
INSERT INTO test_sync VALUES (1, 'sync test');
# 从库执行
SELECT * FROM test_sync;
```

# 2. 一主一从切换
P12之前：pg_ctl promote shell、触发器方式，recovery.conf: trigger_file

P12：pg_promote()函数（true,60）=> select pg_promote(true,60);

## 2.1. 主从切换
关闭主库61，模拟主库故障
```shell
systemctl stop postgresql
# 或
pg_ctl stop -m fast
```

激活从库62，提升从库为主库

```shell
psql -U postgres -c "select pg_promote(true,60);"
pg_controldata
# 注意查看
# Database cluster state:               in production
```
插入数据验证
```shell
psql -U postgres -c "insert into test_sync values (2, 'switch test');"
psql -U postgres -c "select * from test_sync;"
```

## 2.2. 旧主库 61 作为备库运行

新主库 62 注释掉连接信息，重启数据库
```shell
sed -i 's/primary_conninfo/#primary_conninfo/' /data/5432/data/postgresql.conf
systemctl restart postgresql
```

旧主库 61 清除数据，根据情况判断是否需要备份
```shell
rm -rf /data/5432/data/*
cd /data/5432
su -s /bin/bash postgres -c "pg_basebackup -h 10.0.0.62 -p 5432 -U repl_user -D /data/5432/data -F p -P -R -l backup20260419"
# 查看会产生一个标识文件：standby.signal
ll /data/5432/data/standby.signal
# 增加连接信息
sed -i "s/#primary_conninfo/primary_conninfo/" /data/5432/data/postgresql.conf
sed -i "s/host=10.0.0.61 port=5432/host=10.0.0.62 port=5432/" /data/5432/data/postgresql.conf
# 启动从库
systemctl start postgresql
```

测试
```shell
# 旧主库 61 查看数据验证
psql -U postgres -c "select * from test_sync;"
# 从库执行
psql -U postgres -c "SELECT pg_is_in_recovery();"
# 主库执行
psql -U postgres -x -c "SELECT * FROM pg_stat_replication;"
```

## 2.3. 旧主库 61 重新作为主库运行
旧主库 61 注释掉连接信息，重启数据库
```shell
systemctl stop postgresql
rm -rf /data/5432/data/standby.signal
sed -i 's/primary_conninfo/#primary_conninfo/' /data/5432/data/postgresql.conf
systemctl start postgresql
```

新主库 62 清除数据，根据情况判断是否需要备份
```shell
systemctl stop postgresql
rm -rf /data/5432/data/*
cd /data/5432
su -s /bin/bash postgres -c "pg_basebackup -h 10.0.0.61 -p 5432 -U repl_user -D /data/5432/data -F p -P -R -l backup20260419"
# 查看会产生一个标识文件：standby.signal
ll /data/5432/data/standby.signal
# 增加连接信息
sed -i "s/#primary_conninfo/primary_conninfo/" /data/5432/data/postgresql.conf
sed -i "s/host=10.0.0.62 port=5432/host=10.0.0.61 port=5432/" /data/5432/data/postgresql.conf
# 启动从库
systemctl start postgresql
```
测试
```shell
# 旧主库 61 查看数据验证
psql -U postgres -c "select * from test_sync;"
psql -U postgres -c "insert into test_sync values (3, 'switch back test');"
# 从库执行
psql -U postgres -c "select * from test_sync;"
psql -U postgres -c "SELECT pg_is_in_recovery();"
# 主库执行
psql -U postgres -x -c "SELECT * FROM pg_stat_replication;"
```
# 3. 一主两从扩容节点

## 1.1. 删除从库的数据目录

```shell
# 从库执行
systemctl stop postgresql
cd /data/5432/backup
tar -zcvf data_backup_$(date +%Y%m%d%H%M%S).tar.gz -C /data/5432/data .
rm -rf /data/5432/data/*
```

## 1.2. 从库拉取主库数据

```shell
# 启动主库
systemctl start postgresql

# 从库执行
# -F p : 以纯格式进行备份，生成一个包含 SQL 语句的文本文件
# -P : 显示备份进度
# -R : 在备份完成后自动生成 standby.conf 标识文件，同时把 recovery (pg11) 配置从库连接的参数转移到 postgresql.conf 文件中了
# -l : backup20260419 : 备份文件的标签，便于识别和管理
cd /data/5432
su -s /bin/bash postgres -c "pg_basebackup -h 10.0.0.61 -p 5432 -U repl_user -D /data/5432/data -F p -P -R -l backup20260419"

# 查看会产生一个标识文件：standby.signal
# 增加连接信息
echo "primary_conninfo = 'host=10.0.0.61 port=5432 user=repl_user password=123456'" >> /data/5432/data/postgresql.conf
# 从库启动
systemctl start postgresql
```

## 1.3. 查看主从复制状态

```shell
# 主库执行
psql -U postgres -x -c "SELECT * FROM pg_stat_replication;"
# 从库执行
psql -U postgres -c "SELECT pg_is_in_recovery();"
```

## 1.4. 主从复制验证
```shell
# 从库执行
SELECT * FROM test_sync;
```
## 4. 关于自定义表空间使用的注意事项

1. 关于 pg_basebackup 备份工具的使用：pg_basebackup 只能备份默认的数据目录，无法直接备份自定义表空间的数据目录。因此，在使用 pg_basebackup 进行备份时，需要确保自定义表空间的数据目录已经正确配置并且包含在备份范围内。

2. 在主从复制环境中，如果主库使用了自定义表空间，那么从库也必须配置相同的自定义表空间路径，并且确保从库能够访问到该路径。否则，从库在启动时可能会因为找不到表空间而无法正常运行。

举例：
```shell
# 主、从库都需要执行以下命令来创建相同的自定义表空间
mkdir -p /data/5432/custom_tablespace
chown postgres:postgres /data/5432/custom_tablespace

# 主创建用户 custom_user
create user custom_user with password '123456' nocreatedb;
# 主创建自定义表空间
create tablespace custom_tablespace location '/data/5432/custom_tablespace' owner custom_user;
# 主创建数据库
create database custom_db tablespace custom_tablespace owner custom_user;
# 主创建表
create table custom_table (id int, info text) tablespace custom_tablespace;
# 主插入数据
insert into custom_table values (1, 'custom tablespace test');
```
