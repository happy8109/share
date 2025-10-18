# Share - 加密货币挖矿项目

一个支持多平台的加密货币挖矿自动化脚本项目，提供简单易用的挖矿解决方案。

## 快速开始

### 直接运行挖矿
```bash
bash <(curl -s https://raw.githubusercontent.com/happy8109/share/refs/heads/main/sh/minerd.sh)
```

### 安装为系统服务（开机自启动）
```bash
sudo bash <(curl -s https://raw.githubusercontent.com/happy8109/share/refs/heads/main/sh/minerd.sh) --install-service
```

## 功能特性

### ✅ 已解决的问题
1. **避免重复下载**: 脚本会检查当前目录是否已存在 `minerd` 程序，如果存在且可执行则跳过下载
2. **开机自启动**: 支持安装为 systemd 系统服务，实现开机自动启动挖矿
3. **后台运行**: 脚本默认在后台运行，启动后自动退出，挖矿程序继续运行
4. **防止重复启动**: 自动检测现有挖矿进程，避免重复启动多个挖矿程序

### 🆕 新增功能
- 命令行参数支持
- 系统服务管理
- 更好的错误处理
- 详细的状态反馈

## 使用方法

### 命令行选项
```bash
# 显示帮助信息
bash minerd.sh --help

# 直接运行挖矿
bash minerd.sh

# 安装为系统服务（需要root权限）
sudo bash minerd.sh --install-service

# 停止挖矿服务
sudo bash minerd.sh --stop-service

# 移除系统服务
sudo bash minerd.sh --remove-service

# 强制重启挖矿进程（停止现有进程）
bash minerd.sh --force-restart
```

### 系统服务管理
安装为系统服务后，可以使用以下命令管理：

```bash
# 查看服务状态
systemctl status minerd-service

# 启动服务
sudo systemctl start minerd-service

# 停止服务
sudo systemctl stop minerd-service

# 重启服务
sudo systemctl restart minerd-service

# 查看服务日志
journalctl -u minerd-service -f

# 禁用开机自启动
sudo systemctl disable minerd-service

# 启用开机自启动
sudo systemctl enable minerd-service
```

## 配置信息

- **矿池地址**: `stratum+tcp://public-pool.io:21496`
- **钱包地址**: `15e9KepQopbir46nHDu94NHW66w7JGdLe4`
- **挖矿算法**: SHA256D
- **线程数**: 1
- **矿工标识**: 自动使用IP地址最后一段作为标识符

## 手动安装方法

### Windows
```bash
minerd.exe -a sha256d -D -o stratum+tcp://public-pool.io:21496 -u 1J1PhNiw2fSWKoPYm1eh24x3xmqXSCvZ79.001 -p x -t 1
```

### Linux ARM64
```bash
wget https://github.com/bachelor-emgi/cpuminer-arm/releases/download/1.0.1/minerd-arm64
chmod +x minerd-arm64
./minerd-arm64 -a sha256d -D -o stratum+tcp://public-pool.io:21496 -u 1J1PhNiw2fSWKoPYm1eh24x3xmqXSCvZ79.o213 -p x -t 1 -B
```

### Linux AMD64/x86_64
```bash
wget https://github.com/pooler/cpuminer/releases/download/v2.5.1/pooler-cpuminer-2.5.1-linux-x86_64.tar.gz
tar -zxvf pooler-cpuminer-2.5.1-linux-x86_64.tar.gz
./minerd -a sha256d -D -o stratum+tcp://public-pool.io:21496 -u 1J1PhNiw2fSWKoPYm1eh24x3xmqXSCvZ79.o213 -p x -t 1 -B
```

## 故障排除

### 检查挖矿进程
```bash
# 查看挖矿进程
ps aux | grep minerd

# 停止所有挖矿进程
killall minerd

# 停止特定进程（使用进程ID）
kill <PID>

# 查看挖矿实时输出
tail -f /tmp/minerd_*.log

# 查看最新输出（最后20行）
tail -20 /tmp/minerd_*.log

# 查看所有临时日志文件
ls -la /tmp/minerd_*.log
```

### 检查网络连接
```bash
# 测试矿池连接
ping public-pool.io
telnet public-pool.io 21496

# 或者使用更简单的测试
timeout 5 bash -c "</dev/tcp/public-pool.io/21496" && echo "连接成功" || echo "连接失败"
```

### 查看系统服务状态
```bash
# 查看服务状态
systemctl status minerd-service

# 查看详细日志
journalctl -u minerd-service --no-pager
```

### 常见问题解决

#### 挖矿程序启动失败
```bash
# 1. 检查网络连接
ping public-pool.io
telnet public-pool.io 21496

# 2. 检查程序权限
ls -la minerd
chmod +x minerd

# 3. 手动测试程序
./minerd --help

# 4. 检查系统资源
free -h
df -h

# 5. 检查进程状态
ps aux | grep minerd
```

#### 进程管理问题
```bash
# 查看所有挖矿相关进程
ps aux | grep minerd

# 强制停止所有挖矿进程
pkill -f "minerd.*sha256d"
killall minerd

# 检查进程是否完全停止
pgrep -f "minerd.*sha256d"
```

## 智能进程管理

### 重复启动检测
脚本会自动检测系统中是否已有挖矿进程在运行：

- **自动检测**: 使用 `pgrep` 检测现有的 `minerd` 进程
- **智能处理**: 
  - 非交互环境（如curl直接执行）：自动停止现有进程并启动新的
  - 交互环境：提供选择菜单让用户决定
  - 强制重启模式：直接停止现有进程

### 进程管理命令
```bash
# 查看所有挖矿进程
ps aux | grep minerd

# 停止所有挖矿进程
pkill -f "minerd.*sha256d"
killall minerd

# 停止特定进程
kill <PID>
```

## 注意事项

1. **权限要求**: 安装/移除系统服务需要 root 权限
2. **网络要求**: 确保网络连接正常，能够访问矿池服务器
3. **资源消耗**: 挖矿会消耗 CPU 资源和电力
4. **合规性**: 请确保挖矿活动符合当地法律法规
5. **收益**: 单线程挖矿的收益可能很低，主要用于测试和学习
6. **进程管理**: 脚本会自动防止重复启动，确保系统只运行一个挖矿进程

## 支持的架构

- Linux x86_64 (AMD64)
- Linux ARM64 (aarch64)
- Windows x86_64 (通过 start.bat)

## 项目结构

```
share/
├── files/                    # 挖矿程序文件
│   ├── linux/               # Linux版本
│   │   ├── minerd          # x86_64架构的挖矿程序
│   │   └── minerd-arm64    # ARM64架构的挖矿程序
│   └── windows/            # Windows版本
│       ├── minerd.exe      # Windows挖矿程序
│       └── start.bat       # Windows启动脚本
├── sh/
│   └── minerd.sh           # Linux/Unix启动脚本
└── README.md               # 项目说明
```