# Workspace Tools

基于 openEuler 的工作区虚拟化管理工具集，满足Linux 桌面上无缝运行 Windows 应用程序。

## 功能概览

| 组件 | 说明 |
|------|------|
| **workspace-launcher** | 应用启动器 — 管理虚拟机生命周期启动 Windows 应用 |
| **workspace-connect** | 远程桌面连接工具 — 交互式连接到远程工作区 |
| **workspace-config** | 虚拟机图形化配置工具 — 配置 CPU/内存/磁盘/设备透传 |
| **workspace-app** | 应用管理工具 — 添加、删除、列出 Windows 应用 |

## 核心功能

### 1. 虚拟机生命周期管理

- 自动检测虚拟机状态（运行/关机/暂停/崩溃）
- 按需启动、恢复暂停的虚拟机
- 崩溃后自动重启
- 启动超时检测（默认 120 秒）
- 系统休眠检测与时间同步
- 空闲自动暂停（可配置超时时间）

### 2. Windows 应用启动

- 通过自实现的应用RDP协议无缝启动 Windows 应用程序
- 支持预配置应用（`apps/` 目录下的应用配置）
- Linux 目录自动映射到 Windows（驱动重定向）
- 剪贴板共享
- 进程管理与清理

### 3. 远程桌面连接

- 交互式连接远程工作区
- 多级配置文件自动发现（命令行 > 环境变量 > 当前目录 > 程序目录 > 用户目录）
- 配置持久化与复用
- 连接状态检查

### 4. 虚拟机图形化配置

- CPU 核心数配置（1-16 核）
- 内存大小配置（512MB-32GB）
- 多磁盘管理（支持 SATA/virtio 总线）
- USB 设备透传（基于 lsusb 扫描）
- PCI 设备透传（基于 lspci 扫描，支持 IOMMU）
- 配置备份与恢复
- 直接读写 虚拟机XML 配置文件

### 5. 应用管理

- 交互式添加 Windows 应用（指定路径、图标、驱动映射）
- 创建桌面快捷方式和系统菜单项
- 应用列表查看与删除

## 快速开始

### 配置

编辑 `workspace.conf`：

```bash
VM_NAME="WorkspaceVM"
WS_IP="192.168.122.28"
WS_USER="your_username"
WS_PASS="your_password"
```

### 使用方式

```bash
# 启动 Windows 应用
./workspace-launcher <应用名>

# 连接远程桌面
./workspace-connect remote

# 图形化配置虚拟机
sudo ./workspace-config

# 管理应用
./workspace-app add          # 添加应用
./workspace-app list         # 列出应用
./workspace-app remove <名称>  # 删除应用
```
