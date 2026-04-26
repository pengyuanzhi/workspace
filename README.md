# Workspace Tools

基于 openEuler 的工作区虚拟化管理工具集，通过 libvirt/KVM 虚拟机和 RDP 协议在 Linux 桌面上无缝运行 Windows 应用程序。

## 功能概览

| 组件 | 说明 |
|------|------|
| **workspace-launcher** | 应用启动器 — 管理虚拟机生命周期，通过 FreeRDP 启动 Windows 应用 |
| **workspace-connect** | 远程桌面连接工具 — 交互式连接到远程工作区 |
| **workspace-config** | 虚拟机图形化配置工具（PyQt5）— 配置 CPU/内存/磁盘/设备透传 |
| **workspace-app** | 应用管理工具 — 添加、删除、列出 Windows 应用 |
| **compile.sh** | 编译脚本 — 将源码编译为二进制（PyInstaller + shc） |
| **package-rpm.sh** | RPM 打包脚本 — 生成可通过 dnf 安装的 RPM 包 |

## 核心功能

### 1. 虚拟机生命周期管理

- 自动检测虚拟机状态（运行/关机/暂停/崩溃）
- 按需启动、恢复暂停的虚拟机
- 崩溃后自动重启
- 启动超时检测（默认 120 秒）
- 系统休眠检测与时间同步
- 空闲自动暂停（可配置超时时间）

### 2. Windows 应用启动

- 通过 FreeRDP 无缝启动 Windows 应用程序
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
- 直接读写 libvirt XML 配置文件

### 5. 应用管理

- 交互式添加 Windows 应用（指定路径、图标、驱动映射）
- 创建桌面快捷方式和系统菜单项
- 应用列表查看与删除

### 6. 编译与打包

- Python 脚本通过 PyInstaller 编译为独立二进制
- Bash 脚本通过 shc 编译为二进制
- 生成标准 RPM 包，支持通过 dnf/yum 安装
- 默认安装路径：`/opt/workspace`

## 快速开始

### 前置条件

- openEuler / Linux 系统
- libvirt + KVM 虚拟化环境
- FreeRDP（xfreerdp）
- PyQt5（仅配置工具需要）

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
sudo ./workspace-config.py

# 管理应用
./workspace-app.sh add          # 添加应用
./workspace-app.sh list         # 列出应用
./workspace-app.sh remove <名称>  # 删除应用

# 编译
./compile.sh

# 打包 RPM
./package-rpm.sh
```

## 项目结构

```
.
├── workspace-launcher.sh   # 应用启动器
├── workspace-connect.sh    # 远程桌面连接工具
├── workspace-config.py     # 虚拟机配置工具（PyQt5 GUI）
├── workspace-app.sh        # 应用管理工具
├── workspace.conf          # 配置文件
├── workspace-tools.spec    # RPM 打包规格文件
├── compile.sh              # 编译脚本
├── package-rpm.sh          # RPM 打包脚本
├── apps/                   # 预配置应用目录
│   ├── LU_Measurement/     # LU 测量应用
│   └── TomoView210/        # TomoView 应用
├── docs/                   # 文档
└── test/                   # 测试脚本
```

## 许可证

Proprietary
