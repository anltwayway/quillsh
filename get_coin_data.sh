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

# 选择要提取几小时的收益数据, 默认为 1 小时
echo "==============================================="
echo "请输入要提取的小时数（按下任意其他按键则默认为 1 小时）："
# 根据输入的数字将变量hours赋值
read -r hours
# 如果用户未输入任何内容，则使用默认值
: ${hours:=1}
echo "请输入每月的成本USD（按下任意其他按键则默认为 100 USD）："
# 根据输入的数字将变量hours赋值
read -r cost_month_usd
# 如果用户未输入任何内容，则使用默认值
: ${cost_month_usd:=100}
echo "提取最近 $hours 小时的收益数据..."

# 临时文件用于存储未排序数据
temp_file=$(mktemp)
# 临时文件用于存储每小时收益情况
hours_reward_file=$(mktemp)

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

        # 获取当前时间和n小时前的时间戳
        current_time=$(date "+%d/%m/%Y %H.%M.%S")
        hours_ago=$(date -d "$hours hour ago" "+%d/%m/%Y %H.%M.%S")

        # 输出时间范围和当前条目的时间戳，用于调试
        # echo "当前时间: $current_time, $hour小时前: $one_hour_ago, 当前条目时间戳: $formatted_timestamp"

        # 判断该时间戳是否在最近一小时内
        if [[ "$formatted_timestamp" > "$hours_ago" ]] && [[ "$formatted_timestamp" < "$current_time" ]]; then
            # echo "匹配到的条目: $amount QUIL"  # 打印匹配的条目
            # 检查 amount 是否是有效数字
            if [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                total_benefit=$(echo "$total_benefit + $amount" | bc)
                echo "$amount" >> "$hours_reward_file"
            else
                echo "无效的金额：$amount"
            fi
        fi
        
        # 将提取和处理后的数据写入临时文件
        echo "$amount,$coin_id,$frame,$formatted_timestamp," >> "$temp_file"
    fi

done


# 按 Frame 排序（数字升序）
sort -t, -k3,3n "$temp_file" >> "$output_file"

# 数据保存完成的消息
echo "数据已保存到 $output_file，按 Frame 排序完成。"

echo "==============================================="
# 输出累计reward_file收益最大值

reward_file="$hours_reward_file"

# 提取最大值
max_benefit=$(sort -t, -k1,1nr "$reward_file" | head -n 1 | awk -F, '{print $1}')
echo "最近$hours 小时的最大收益: $max_benefit QUIL"

# 提取最小值
# 倒序后提取第三行
min_benefit=$(sort -t, -k1,1nr "$reward_file" | tail -n +3 | tail -n 1 | awk -F, '{print $1}')
echo "最近$hours 小时的最小收益: $min_benefit QUIL"

# 计算平均值
average_benefit=$(awk -F, '{sum += $1} END {if (NR > 0) print sum / NR}' "$reward_file")
echo "最近$hours 小时的平均收益: $average_benefit QUIL"

# 计算累计值
total_benefit=$(awk -F, '{sum += $1} END {print sum}' "$reward_file")
echo "最近$hours 小时的累计收益: $total_benefit QUIL"

# 计算总条目数
total_entries=$(wc -l < "$reward_file")
echo "最近$hours 小时的总frame数: $total_entries"

echo "==============================================="
# 根据最近$hour小时收益推算每天收益以及每月收益, 并给出quil按照0.12usd价格换算得到的usd的价值
# 1. 每小时收益 * 24 = 每天收益
daily_benefit=$(echo "$total_benefit * 24 / $hours" | bc)
# 按照收益*0.12usd计算
daily_benefit_usd=$(echo "$daily_benefit * 0.12" | bc)
echo "按照最近$hours 小时推算，假定Quil价格为0.12usd"
echo "每天的收益: $daily_benefit QUIL"
echo "每天的收益: $daily_benefit_usd USD"
# 2. 每天收益 * 30 = 每月收益
monthly_benefit=$(echo "$daily_benefit * 30" | bc)
# 按照收益*0.12usd计算
monthly_benefit_usd=$(echo "$monthly_benefit * 0.12" | bc)
echo "每月的收益: $monthly_benefit QUIL"
echo "每月的收益: $monthly_benefit_usd USD"
echo "每月的成本为 $cost_month_usd USD，收益率为"
# 计算收益率
monthly_benefit_usd_percent=$(echo "scale=2; $monthly_benefit_usd / 557.53 * 100" | bc)
echo "$monthly_benefit_usd_percent %"

echo "==============================================="
# 输出累计reward_file收益最大值

reward_file="$output_file"

# 提取最大值
max_benefit=$(sort -t, -k1,1nr "$reward_file" | head -n 1 | awk -F, '{print $1}')
echo "累计最大收益: $max_benefit QUIL"

# 提取最小值（跳过表头后按最大值排序，取最后一行）
min_benefit=$(tail -n +2 "$reward_file" | sort -t, -k1,1nr | tail -n 1 | awk -F, '{print $1}')

echo "累计最小收益: $min_benefit QUIL"

# 计算平均值
average_benefit=$(awk -F, '{sum += $1} END {if (NR > 0) print sum / NR}' "$reward_file")
echo "累计平均收益: $average_benefit QUIL"

# 计算累计值
total_benefit=$(awk -F, '{sum += $1} END {print sum}' "$reward_file")
echo "累计收益: $total_benefit QUIL"

# 计算总条目数
total_entries=$(wc -l < "$reward_file")
echo "总frame数: $total_entries"

# 删除临时文件
rm "$temp_file"
rm "$hours_reward_file"
rm "$reward_file"

# 如果此时的时间大于23点，执行一个命令
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
# 输出节点信息
echo "输出节点信息..."
cd "$HOME/ceremonyclient/node" && NODE_BINARY=$(find . -type f -executable -name "node-*" ! -name "*.dgst*" ! -name "*.sig*" | sort -V | tail -n 1 | xargs basename) && ./$NODE_BINARY -node-info

