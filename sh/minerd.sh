#!/bin/bash

# 定义矿池钱包地址变量
WALLET_ADDRESS="15e9KepQopbir46nHDu94NHW66w7JGdLe4"
POOL_URL="stratum+tcp://public-pool.io:21496"
POOL_PASSWORD="x"
THREADS="1" # 默认挖矿线程数

# 尝试自动查找活动网卡
interface=$(ip route | grep default | awk '{print $5}')

# 检查是否找到网卡
if [ -z "$interface" ]; then
    echo "Error: Unable to automatically detect network interface."
    echo "Using random string as fallback for worker identifier."

    # 生成 4 位随机字符串
    identifier=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c4)

else

    # 从活动网卡获取 IP 地址
    ip_address=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    # 检查是否成功获取 IP 地址
    if [ -z "$ip_address" ]; then
        echo "Error: Unable to retrieve IP address from interface '$interface'."
        echo "Using random string as fallback for worker identifier."

        # 生成 4 位随机字符串
        identifier=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c4)
    else
        # 提取 IP 地址的最后一段
        identifier=$(echo "$ip_address" | awk -F. '{print $4}')

          # 检查是否成功提取标识符
	    if [ -z "$identifier" ]; then
	        echo "Error: Unable to extract identifier from IP address."
	        echo "Using random string as fallback for worker identifier."
	        # 生成 4 位随机字符串
        	identifier=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c4)
	    fi

    fi

fi

# 构建完整的矿工用户名
# 格式为 YourWalletAddress.WorkerName
MINER_USERNAME="${WALLET_ADDRESS}.${identifier}"

# 输出构建的矿工用户名 (调试用)
echo "Miner Username: ${MINER_USERNAME}"

# 构建 Minerd 下载命令的变量
MINERD_AMD64_URL="https://github.com/happy8109/share/raw/refs/heads/main/files/linux/minerd"
MINERD_ARM64_URL="https://github.com/happy8109/share/raw/refs/heads/main/files/linux/minerd-arm64"
MINERD_EXECUTABLE_NAME="minerd" # 最终的可执行文件名

# 判断系统架构并下载对应的 minerd
if [[ $(uname -m) == "x86_64" ]]; then  # 或 amd64
    echo "Detected AMD64 architecture, downloading ${MINERD_EXECUTABLE_NAME}."
    wget "${MINERD_AMD64_URL}" -O "${MINERD_EXECUTABLE_NAME}"
elif [[ $(uname -m) == "aarch64" ]]; then # ARM64 系统
    echo "Detected ARM64 architecture, downloading ${MINERD_EXECUTABLE_NAME}-arm64."
    wget "${MINERD_ARM64_URL}" -O "${MINERD_EXECUTABLE_NAME}"
else
    echo "Unsupported architecture: $(uname -m). Assuming ARM64 for now and trying to download ${MINERD_EXECUTABLE_NAME}-arm64."
    wget "${MINERD_ARM64_URL}" -O "${MINERD_EXECUTABLE_NAME}" # 尝试下载 ARM 版本作为回退
fi

# 检查是否下载成功
if [ ! -f "${MINERD_EXECUTABLE_NAME}" ]; then
    echo "Error: Failed to download the minerd executable."
    exit 1
fi

# 赋予执行权限
chmod +x "${MINERD_EXECUTABLE_NAME}"

# 构建并执行 minerd 命令
# 参数: -a 算法, -D (在后台运行), -o 矿池地址, -u 用户名, -p 密码, -t 线程数, -B (后台运行)
echo "Starting miner with username: ${MINER_USERNAME}"
"${MINERD_EXECUTABLE_NAME}" -a sha256d -D -o "${POOL_URL}" -u "${MINER_USERNAME}" -p "${POOL_PASSWORD}" -t "${THREADS}" -B

echo "Miner command executed. Check your pool dashboard for worker status."
