#!/bin/bash

# 定义矿池钱包地址变量
WALLET_ADDRESS="15e9KepQopbir46nHDu94NHW66w7JGdLe4"
POOL_URL="stratum+tcp://public-pool.io:21496"
POOL_PASSWORD="x"
THREADS="1" # 默认挖矿线程数

# 定义脚本选项
INSTALL_SERVICE=false
STOP_SERVICE=false
REMOVE_SERVICE=false
MINERD_EXECUTABLE_NAME="minerd"
SERVICE_NAME="minerd-service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --install-service    安装为系统服务（开机自启动）"
    echo "  --stop-service       停止挖矿服务"
    echo "  --remove-service     移除系统服务"
    echo "  --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                  直接运行挖矿"
    echo "  $0 --install-service 安装为系统服务"
    echo "  $0 --stop-service    停止服务"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-service)
            INSTALL_SERVICE=true
            shift
            ;;
        --stop-service)
            STOP_SERVICE=true
            shift
            ;;
        --remove-service)
            REMOVE_SERVICE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查是否以root权限运行（安装服务时需要）
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "错误: 安装/移除服务需要root权限，请使用sudo运行"
        exit 1
    fi
}

# 停止挖矿服务
stop_mining_service() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "正在停止挖矿服务..."
        systemctl stop "$SERVICE_NAME"
        echo "挖矿服务已停止"
    else
        echo "挖矿服务未运行"
    fi
}

# 移除系统服务
remove_mining_service() {
    check_root
    
    stop_mining_service
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "正在禁用服务..."
        systemctl disable "$SERVICE_NAME"
    fi
    
    if [[ -f "$SERVICE_FILE" ]]; then
        echo "正在移除服务文件..."
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        echo "服务已移除"
    else
        echo "服务文件不存在"
    fi
}

# 安装为系统服务
install_as_service() {
    check_root
    
    # 检查minerd程序是否存在
    if [[ ! -f "./$MINERD_EXECUTABLE_NAME" ]]; then
        echo "错误: 未找到minerd程序，请先运行脚本下载程序"
        exit 1
    fi
    
    # 创建服务文件
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Miner Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/$MINERD_EXECUTABLE_NAME -a sha256d -D -o $POOL_URL -u $WALLET_ADDRESS.\$(ip route | grep default | awk '{print \$5}' | xargs -I {} ip addr show {} | grep "inet " | awk '{print \$2}' | cut -d'/' -f1 | awk -F. '{print \$4}') -p $POOL_PASSWORD -t $THREADS -B
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd并启用服务
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    echo "挖矿服务已安装并启动"
    echo "使用以下命令管理服务:"
    echo "  查看状态: systemctl status $SERVICE_NAME"
    echo "  停止服务: systemctl stop $SERVICE_NAME"
    echo "  启动服务: systemctl start $SERVICE_NAME"
    echo "  查看日志: journalctl -u $SERVICE_NAME -f"
}

# 处理服务相关操作
if [[ "$STOP_SERVICE" == true ]]; then
    stop_mining_service
    exit 0
fi

if [[ "$REMOVE_SERVICE" == true ]]; then
    remove_mining_service
    exit 0
fi

if [[ "$INSTALL_SERVICE" == true ]]; then
    install_as_service
    exit 0
fi

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

# 检查是否已存在minerd程序
if [[ -f "${MINERD_EXECUTABLE_NAME}" ]]; then
    echo "发现已存在的 ${MINERD_EXECUTABLE_NAME} 程序"
    
    # 检查文件是否可执行
    if [[ -x "${MINERD_EXECUTABLE_NAME}" ]]; then
        echo "程序已存在且可执行，跳过下载"
    else
        echo "程序存在但不可执行，重新赋予执行权限"
        chmod +x "${MINERD_EXECUTABLE_NAME}"
    fi
else
    echo "未找到 ${MINERD_EXECUTABLE_NAME} 程序，开始下载..."
    
    # 判断系统架构并下载对应的 minerd
    if [[ $(uname -m) == "x86_64" ]]; then  # 或 amd64
        echo "检测到 AMD64 架构，正在下载 ${MINERD_EXECUTABLE_NAME}..."
        if wget "${MINERD_AMD64_URL}" -O "${MINERD_EXECUTABLE_NAME}"; then
            echo "AMD64 版本下载成功"
        else
            echo "错误: AMD64 版本下载失败"
            exit 1
        fi
    elif [[ $(uname -m) == "aarch64" ]]; then # ARM64 系统
        echo "检测到 ARM64 架构，正在下载 ${MINERD_EXECUTABLE_NAME}..."
        if wget "${MINERD_ARM64_URL}" -O "${MINERD_EXECUTABLE_NAME}"; then
            echo "ARM64 版本下载成功"
        else
            echo "错误: ARM64 版本下载失败"
            exit 1
        fi
    else
        echo "不支持的架构: $(uname -m)，尝试下载 ARM64 版本作为回退..."
        if wget "${MINERD_ARM64_URL}" -O "${MINERD_EXECUTABLE_NAME}"; then
            echo "ARM64 版本下载成功（回退）"
        else
            echo "错误: ARM64 版本下载失败"
            exit 1
        fi
    fi
    
    # 检查是否下载成功
    if [[ ! -f "${MINERD_EXECUTABLE_NAME}" ]]; then
        echo "错误: 下载失败，未找到 ${MINERD_EXECUTABLE_NAME} 文件"
        exit 1
    fi
    
    # 赋予执行权限
    echo "正在设置执行权限..."
    chmod +x "${MINERD_EXECUTABLE_NAME}"
    echo "执行权限设置完成"
fi

# 构建并执行 minerd 命令
# 参数: -a 算法, -D (在后台运行), -o 矿池地址, -u 用户名, -p 密码, -t 线程数, -B (后台运行)
echo "=========================================="
echo "挖矿配置信息:"
echo "  矿池地址: ${POOL_URL}"
echo "  钱包地址: ${WALLET_ADDRESS}"
echo "  矿工名称: ${MINER_USERNAME}"
echo "  挖矿线程: ${THREADS}"
echo "  挖矿算法: SHA256D"
echo "=========================================="

echo "正在启动挖矿程序..."
if ./"${MINERD_EXECUTABLE_NAME}" -a sha256d -D -o "${POOL_URL}" -u "${MINER_USERNAME}" -p "${POOL_PASSWORD}" -t "${THREADS}" -B; then
    echo "挖矿程序启动成功！"
    echo ""
    echo "提示:"
    echo "  - 挖矿程序已在后台运行"
    echo "  - 请访问矿池网站查看挖矿状态"
    echo "  - 使用 'ps aux | grep minerd' 查看进程"
    echo "  - 使用 'killall minerd' 停止挖矿"
    echo ""
    echo "如需安装为系统服务（开机自启动），请运行:"
    echo "  sudo bash $0 --install-service"
else
    echo "错误: 挖矿程序启动失败"
    echo "请检查网络连接和矿池配置"
    exit 1
fi
