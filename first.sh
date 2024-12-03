#!/bin/bash
# first.sh

# 1. 配置DNS
echo "Updating /etc/resolv.conf..."
sudo bash -c 'cat > /etc/resolv.conf' << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# config NetworkManager(if exist)
if [ -d "/etc/NetworkManager" ]; then
  echo "Configuring NetworkManager..."
  sudo mkdir -p /etc/NetworkManager/conf.d
  sudo bash -c 'cat > /etc/NetworkManager/conf.d/dns.conf' << EOF
[main]
dns=none
EOF

  echo "Restarting NetworkManager..."
  sudo systemctl restart NetworkManager
fi

# config DHCP 
if [ -f "/etc/dhcp/dhclient.conf" ]; then
  echo "Configuring DHCP client..."
  sudo bash -c 'cat >> /etc/dhcp/dhclient.conf' << EOF

# Added by script to use Google's DNS
supersede domain-name-servers 8.8.8.8, 8.8.4.4;
EOF

  echo "Restarting networking service..."
  sudo systemctl restart networking
else
  echo "DHCP client configuration file not found."
fi

echo "DNS settings updated to use 8.8.8.8 and 8.8.4.4."

# 2. 打开防火墙端口
sudo ufw allow from 212.56.32.238 to any port 40000:41000 proto tcp

# 3. 安装start-cluster.sh
wget https://raw.githubusercontent.com/anltwayway/quillsh/refs/heads/main/start-cluster.sh

chmod +x start-cluster.sh

# 5. 开始下载和安装软件
wget -O ~/qone.sh https://github.com/lamat1111/QuilibriumScripts/raw/main/qone.sh && chmod +x ~/qone.sh && ./qone.sh
