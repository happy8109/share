# Share 挖矿一键脚本

## 介绍

适用于 Linux (systemd/ARM64/AMD64/OpenWrt) 的自动化加密货币挖矿脚本。一键运行与维护、带人性化交互菜单，可自动开机自启、智能进程管理，支持一键清理测试环境。

## 快速开始

```bash
curl -fsSL -o minerd.sh https://raw.githubusercontent.com/happy8109/share/refs/heads/main/sh/minerd.sh && chmod +x minerd.sh && bash minerd.sh
```
- 首次 root 运行自动安装自启服务
- 普通用户可菜单管理各项功能

## 功能特性
- 交互菜单：一键管理自启/进程/日志/清场等
- 自动判断系统并安装 systemd/OpenWrt 服务
- 菜单选项与服务启动体验彻底分离：服务模式自动后台启动，手动启动才有菜单
- 智能防止重复进程
- 一键清场：停止服务、杀进程、清理日志、删除二进制

## 脚本使用

### 交互菜单（推荐主入口）
仅手动运行、无参数、交互终端时显示：
```
bash sh/minerd.sh
```
菜单操作：
  1) 立即启动挖矿进程
  2) 安装为开机自启（systemd/OpenWrt）
  3) 停止自启服务
  4) 移除自启服务
  5) 查看自启服务状态
  6) 查看服务日志(实时)
  7) 查看挖矿进程状态
  8) 停止挖矿进程
  9) 显示网络/标识信息
 10) 一键清场（停止进程+移除服务+清理文件）
  0) 退出

服务场景/一键运行不会中断或等待菜单。

### 命令行参数
辅助运维与手动自动化管理，详见 `--help` 输出：
```bash
bash sh/minerd.sh --install-service    # 安装自启
bash sh/minerd.sh --stop-service       # 停止服务
bash sh/minerd.sh --remove-service     # 移除服务
bash sh/minerd.sh --force-restart      # 强制重启挖矿
bash sh/minerd.sh --help               # 查看帮助
```

## 主要管理命令
```
systemctl status minerd-service
systemctl restart minerd-service
journalctl -u minerd-service -f
ps aux | grep minerd
```
清场建议直接用菜单“10”，也可用：
```bash
pkill -f 'minerd.*sha256d'
systemctl disable --now minerd-service
rm -f /etc/systemd/system/minerd-service.service
rm -f ./minerd ./minerd-arm64 /tmp/minerd_*.log
systemctl daemon-reload
```

## 配置信息
- 钱包地址、矿池等直接编辑 `sh/minerd.sh`:
  - `WALLET_ADDRESS`、`POOL_URL`、`POOL_PASSWORD`、`THREADS`
- 挖矿标识符自动取 IP 尾段，无需手动调整
- 菜单不支持在线更改配置，须手动编辑脚本

## 常见问题/FAQ
- **无法连接矿池**：请检查网络或切换矿池
- **服务看不到菜单**：设计如此，服务开机自启不涉及交互。
- **脚本升级/清理环境**：优先用菜单10: 一键清场
- **修改参数配置后**：重新运行 `bash sh/minerd.sh --install-service`

## 项目结构
```
sh/
  minerd.sh         # 主脚本
...
```

如需详细定制或有 bug，欢迎提 issue。