wget https://github.com/oliver006/redis_exporter/releases/download/v1.83.0/redis_exporter-v1.83.0.linux-arm64.tar.gz

tar -zxvf redis_exporter-v1.83.0.linux-arm64.tar.gz

cd redis_exporter-v1.83.0.linux-arm64

mv redis_exporter /usr/local/bin/

redis_exporter --version

useradd -r -s /sbin/nologin prometheus

mkdir -pv /data/redis_exporter
echo "123456" > /data/redis_exporter/password.json
chown -R prometheus:prometheus /data/redis_exporter
chown -R prometheus:prometheus /usr/local/bin/redis_exporter
chmod 600 /data/redis_exporter/password

cat > /usr/lib/systemd/system/redis_exporter6379.service <<EOF
[Unit]
Description=Prometheus Redis Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/redis_exporter --redis.password-file /data/redis_exporter/password.json --web.listen-address 0.0.0.0:9121
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start redis_exporter6379
systemctl enable redis_exporter6379
systemctl status redis_exporter6379

# promethus
# scrape_configs:
#  - job_name: 'redis_exporter'
#    static_configs:
#      - targets: ['172.18.26.198:9121']

# sudo systemctl reload prometheus

# https://grafana.com/grafana/dashboards/763-redis-dashboard-for-prometheus-redis-exporter-1-x/

