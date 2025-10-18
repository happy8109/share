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
FORCE_RESTART=false
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
    echo "  --force-restart      强制重启挖矿进程（停止现有进程）"
    echo "  --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                  直接运行挖矿"
    echo "  $0 --install-service 安装为系统服务"
    echo "  $0 --stop-service    停止服务"
    echo "  $0 --force-restart   强制重启挖矿"
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
        --force-restart)
            FORCE_RESTART=true
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

# 检查是否已有挖矿进程在运行
check_existing_miner() {
    # 检查是否有minerd进程在运行
    if pgrep -f "minerd.*sha256d" > /dev/null; then
        echo "检测到已有挖矿进程在运行："
        ps aux | grep -E "minerd.*sha256d" | grep -v grep
        echo ""
        
        # 如果是强制重启模式，直接停止现有进程
        if [[ "$FORCE_RESTART" == true ]]; then
            echo "强制重启模式：正在停止现有挖矿进程..."
            pkill -f "minerd.*sha256d"
            sleep 2
            echo "现有进程已停止"
            return 0
        fi
        
        # 检查是否在非交互环境中（如通过curl直接执行）
        if [[ ! -t 0 ]] || [[ -n "$CI" ]] || [[ -n "$AUTOMATED" ]]; then
            echo "检测到非交互环境，自动停止现有进程并启动新的..."
            pkill -f "minerd.*sha256d"
            sleep 2
            echo "现有进程已停止"
            return 0
        fi
        
        # 交互模式
        echo "请选择操作："
        echo "1) 停止现有进程并启动新的"
        echo "2) 退出脚本"
        echo "3) 查看现有进程状态"
        read -p "请输入选择 (1-3): " choice
        
        case $choice in
            1)
                echo "正在停止现有挖矿进程..."
                pkill -f "minerd.*sha256d"
                sleep 2
                echo "现有进程已停止"
                ;;
            2)
                echo "脚本退出"
                exit 0
                ;;
            3)
                echo "现有挖矿进程状态："
                ps aux | grep -E "minerd.*sha256d" | grep -v grep
                echo ""
                echo "如需停止进程，请运行："
                echo "  pkill -f 'minerd.*sha256d'"
                echo "  killall minerd"
                exit 0
                ;;
            *)
                echo "无效选择，脚本退出"
                exit 1
                ;;
        esac
    fi
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

# 检查现有挖矿进程（仅在直接运行时检查）
check_existing_miner

# 测试网络连接
test_network_connection() {
    echo "正在测试网络连接..."
    
    # 测试矿池服务器连接
    if ping -c 1 -W 3 public-pool.io > /dev/null 2>&1; then
        echo "✓ 矿池服务器连接正常"
    else
        echo "✗ 无法连接到矿池服务器 public-pool.io"
        echo "请检查网络连接或DNS设置"
        return 1
    fi
    
    # 测试矿池端口
    if timeout 5 bash -c "</dev/tcp/public-pool.io/21496" 2>/dev/null; then
        echo "✓ 矿池端口 21496 连接正常"
    else
        echo "✗ 无法连接到矿池端口 21496"
        echo "请检查防火墙设置或矿池状态"
        return 1
    fi
    
    return 0
}

# 执行网络连接测试
if ! test_network_connection; then
    echo ""
    echo "网络连接测试失败，但将继续尝试启动挖矿程序..."
    echo "如果启动失败，请检查网络配置"
    echo ""
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

# 创建临时日志文件路径
TEMP_LOG="/tmp/minerd_$$.log"

# 清理旧的临时日志文件（超过1小时的）
find /tmp -name "minerd_*.log" -mmin +60 -delete 2>/dev/null || true

# 在后台启动挖矿程序，输出到临时文件
nohup ./"${MINERD_EXECUTABLE_NAME}" -a sha256d -D -o "${POOL_URL}" -u "${MINER_USERNAME}" -p "${POOL_PASSWORD}" -t "${THREADS}" -B > "${TEMP_LOG}" 2>&1 &

# 获取进程ID
MINER_PID=$!

# 等待3秒确保程序启动
sleep 3

# 检查进程是否还在运行，并且检查是否有minerd进程在运行
if kill -0 $MINER_PID 2>/dev/null || pgrep -f "minerd.*sha256d" > /dev/null; then
    # 获取实际的minerd进程ID
    ACTUAL_PID=$(pgrep -f "minerd.*sha256d" | head -1)
    if [[ -n "$ACTUAL_PID" ]]; then
        MINER_PID=$ACTUAL_PID
    fi
    
    echo "挖矿程序启动成功！"
    echo ""
    echo "=========================================="
    echo "挖矿程序信息:"
    echo "  进程ID: $MINER_PID"
    echo "  矿工名称: ${MINER_USERNAME}"
    echo "  运行状态: 后台运行中"
    echo "=========================================="
    echo ""
    echo "管理命令:"
    echo "  查看进程: ps aux | grep minerd"
    echo "  停止挖矿: kill $MINER_PID"
    echo "  停止所有: killall minerd"
    echo "  查看输出: tail -f ${TEMP_LOG}"
    echo "  查看最新输出: tail -20 ${TEMP_LOG}"
    echo ""
    echo "如需安装为系统服务（开机自启动），请运行:"
    echo "  sudo bash $0 --install-service"
    echo ""
    echo "脚本将在3秒后退出，挖矿程序继续在后台运行..."
    sleep 3
    exit 0
else
    echo "错误: 挖矿程序启动失败"
    echo "请检查网络连接和矿池配置"
    echo ""
    echo "故障排除步骤:"
    echo "1. 检查网络连接: ping public-pool.io"
    echo "2. 检查矿池端口: telnet public-pool.io 21496"
    echo "3. 检查程序权限: ls -la ${MINERD_EXECUTABLE_NAME}"
    echo "4. 手动测试: ./${MINERD_EXECUTABLE_NAME} --help"
    echo "5. 检查系统资源: free -h && df -h"
    echo ""
    if [[ -f "${TEMP_LOG}" ]]; then
        echo "错误日志内容:"
        echo "----------------------------------------"
        cat "${TEMP_LOG}"
        echo "----------------------------------------"
        # 清理临时日志文件
        rm -f "${TEMP_LOG}"
    fi
    exit 1
fi
