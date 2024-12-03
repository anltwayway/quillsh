#!/bin/bash

# 获取当前日期（格式：YYYY-MM-DD）
current_date=$(date "+%Y-%m-%d")

# 设置输出文件名，带日期
output_file="/root/coin_data_$current_date.csv"

# 进入指定目录并执行命令
cd ~ && cd ceremonyclient/node ||
    { echo "无法进入指定目录，请检查路径。"; exit 1; }

# 执行命令获取输出
output=$(./../client/qclient-2.0.4.1-linux-amd64 token coins metadata --public-rpc)

# 确保输出文件头部
echo "Amount (QUIL),Coin ID,Frame,Timestamp" > "$output_file"

# 临时文件用于存储未排序数据
temp_file=$(mktemp)


# 处理输出并提取需要的字段
total_benefit=0  # 累计收益初始化

echo "$output" | while IFS= read -r line; do
    # 去掉多余的不可见字符
    line=$(echo "$line" | tr -d '\r\n')

    # 使用改进的正则表达式提取数据
    if [[ $line =~ ^([0-9]+\.[0-9]+)\ QUIL\ \(Coin\ (0x[0-9a-fA-F]+)\)\ Frame\ ([0-9]+),\ Timestamp\ ([0-9T:-]+)$ ]]; then
        amount="${BASH_REMATCH[1]}"
        coin_id="${BASH_REMATCH[2]}"
        frame="${BASH_REMATCH[3]}"
        raw_timestamp="${BASH_REMATCH[4]}"

        # 转换时间格式
        formatted_timestamp=$(date -d "${raw_timestamp}" "+%d/%m/%Y %H.%M.%S" 2>/dev/null)

        # 如果时间格式转换失败，使用原时间戳
        if [ -z "$formatted_timestamp" ]; then
            formatted_timestamp="$raw_timestamp"
        fi
        
        # 将提取和处理后的数据写入临时文件
        echo "$amount,$coin_id,$frame,$formatted_timestamp," >> "$temp_file"
    fi

done


# 按 Frame 排序（数字升序）
sort -t, -k3,3n "$temp_file" >> "$output_file"

echo "==============================================="

echo "数据已保存到 $output_file，按 Frame 排序完成。"

# 删除临时文件
rm "$temp_file"

# # 如果此时的时间大于23点，执行一个命令
if [ "$(date +%H)" -gt 23 ]; then
    echo "==============================================="
    echo "当前时间大于 23 点，执行合并token的命令。"
    # 进入指定目录并执行命令
    cd ~ && cd ceremonyclient/node ||
        { echo "无法进入指定目录，请检查路径。"; exit 1; }

    # 执行命令获取输出
    output=$(./../client/qclient-2.0.4.1-linux-amd64 token merge all --public-rpc)
fi

echo "==============================================="