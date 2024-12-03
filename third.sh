#!/bin/bash
# third.sh 替换config

# 1. 停止ceremonyclinet.service
sudo systemctl stop ceremonyclient

# 2. 替换config.yml
cp /root/config.yml /root/ceremonyclient/node/.config/
cp /root/keys.yml /root/ceremonyclient/node/.config/

# 4. 重置服务配置
sudo systemctl daemon-reload

# 6. 启动服务
sudo systemctl start ceremonyclient

# 7. 设置开机自启
sudo systemctl enable ceremonyclient

# 8. 查看服务状态
sudo systemctl status ceremonyclient