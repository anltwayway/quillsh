#!/bin/bash
# second.sh 替换config.yml

# 1. 停止ceremonyclinet.service
sudo systemctl stop ceremonyclient

# 2. 替换config.yml
cp /root/config.yml /root/ceremonyclient/node/.config/
cp /root/keys.yml /root/ceremonyclient/node/.config/

# 3. 修改ceremonyclient.service
# 根据config.yml的配置，修改以下配置文件

# 获取本机的IP地址（假设是 eth0 接口）
local_ip=$(hostname -I | awk '{print $1}')

echo "本机 IP 地址 $local_ip "

# 输入数据（示例）
data=$(cat ceremonyclient/node/.config/config.yml)

# 提取 IP 和端口，并处理端口的后三位
matched_ports=$(echo "$data" | grep -oP '(/ip4/\d+\.\d+\.\d+\.\d+/tcp/\d+)' | grep "$local_ip" | sed -E 's|/ip4/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/tcp/([0-9]+)|\2|' | sed -E 's/.*(...)$/\1/' | sed -E 's/^0+([0-9]+)$/\1/')

# 如果匹配到端口，进行处理
if [[ -n "$matched_ports" ]]; then
# 将端口按升序排序并提取最大和最小值
min_port=$(echo "$matched_ports" | sort -n | head -n 1)
max_port=$(echo "$matched_ports" | sort -n | tail -n 1)
mincore=$((min_port + 1))
maxcore=$((max_port + 1))

# 输出最小和最大端口 +1
echo "匹配到的端口：$matched_ports"
echo "最小端口 +1：$((min_port))"
echo "最大端口 +1：$((max_port))"
else
echo "没有匹配到目标 IP 的端口。"
fi

# 替换/lib/systemd/system/ceremonyclient.service这个内容为
sudo bash -c 'cat > /lib/systemd/system/ceremonyclient.service' << EOF
[Unit]
Description=Quilibrium Node Service (Cluster Mode)

[Service]
Type=simple
Restart=always
RestartSec=50ms
User=root
Group=root
# this WorkingDirectory is needed to find the .config directory
WorkingDirectory=/root/ceremonyclient/node
ExecStart=/root/start-cluster.sh --core-index-start $mincore --data-worker-count $maxcore

EOF

# 4. 重置服务配置
sudo systemctl daemon-reload

# 6. 启动服务
sudo systemctl start ceremonyclient

# 7. 设置开机自启
sudo systemctl enable ceremonyclient

# 8. 查看服务状态
sudo systemctl status ceremonyclient