#!/bin/bash

# 尝试自动查找活动网卡
interface=$(ip route | grep default | awk '{print $5}')

# 检查是否找到网卡
if [ -z "$interface" ]; then
    echo "Error: Unable to automatically detect network interface."
    echo "Using random string as fallback."

    # 生成 4 位随机字符串
    identifier=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c4)

else

    # 从活动网卡获取 IP 地址
    ip_address=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    # 检查是否成功获取 IP 地址
    if [ -z "$ip_address" ]; then
        echo "Error: Unable to retrieve IP address from interface '$interface'."
        echo "Using random string as fallback."

        # 生成 4 位随机字符串
        identifier=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c4)
    else
        # 提取 IP 地址的最后一段
        identifier=$(echo "$ip_address" | awk -F. '{print $4}')

          # 检查是否成功提取标识符
	    if [ -z "$identifier" ]; then
	        echo "Error: Unable to extract identifier from IP address."
	        echo "Using random string as fallback."
	        # 生成 4 位随机字符串
        	identifier=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c4)
	    fi

    fi

fi

# 构建完整的命令
command="./minerd -a sha256d -D -o stratum+tcp://public-pool.io:21496 -u 15e9KepQopbir46nHDu94NHW66w7JGdLe4.${identifier} -p x -t 1 -B"

# 输出构建的命令 (调试用)
echo "Command: $command"

# 判断系统架构
if [[ $(uname -m) == "x86_64" ]]; then  # 或 amd64
    # AMD64 系统
    echo "Detected AMD64 architecture, downloading minerd."
    wget https://github.com/happy8109/share/raw/refs/heads/main/files/linux/minerd
else
    # ARM64 系统或者其他
    echo "Detected non-AMD64 architecture, downloading minerd-arm64."
    wget https://github.com/happy8109/share/raw/refs/heads/main/files/linux/minerd-arm64
    # 重命名为 minerd
    mv minerd-arm64 minerd
fi

# 赋予执行权限
chmod +x minerd

# 执行
./minerd -a sha256d -D -o stratum+tcp://public-pool.io:21496 -u 15e9KepQopbir46nHDu94NHW66w7JGdLe4.${identifier} -p x -t 1 -B

echo "Command executed."
