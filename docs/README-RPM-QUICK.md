# RPM 打包系统 - 快速参考

## ✅ 重要改进

所有脚本现已支持**动态路径配置**，不再写死任何用户名或目录路径！

## 🚀 快速开始

### 最简单的方式

```bash
cd /your/workspace/path
./compile.sh
# 回答 y 进行打包
# 回答 y 进行安装
```

### 自定义安装路径

```bash
WORKSPACE_INSTALL_DIR="/your/custom/path" ./compile.sh
```

### 指定工作区目录

```bash
./compile.sh "/custom/workspace/path"
```

## 📁 核心文件

| 文件 | 说明 |
|------|------|
| `compile.sh` | 编译脚本（支持动态路径） |
| `package-rpm.sh` | 打包脚本（支持动态路径） |
| `workspace-tools.spec` | RPM 规范文件 |
| `test-rpm-build.sh` | 测试脚本 |

## 📚 文档

| 文档 | 说明 |
|------|------|
| `QUICKSTART.md` | 快速开始指南 |
| `README-RPM.md` | 完整文档 |
| `CONFIG-EXAMPLES.md` | 配置示例 |
| `RPM-PACKAGING-SUMMARY.md` | 完整总结 |

## ⚙️ 配置选项

### 环境变量

```bash
# 工作区目录
export WORKSPACE_DIR="/path/to/workspace"

# 安装路径（默认: /opt/workspace）
export WORKSPACE_INSTALL_DIR="/custom/install/path"

# 包版本（默认: 1.0.0）
export WORKSPACE_VERSION="2.0.0"

# 包发布号（默认: 1）
export WORKSPACE_RELEASE="1"
```

### 优先级

```
环境变量 > 命令行参数 > 脚本所在目录
```

## 🎯 使用场景

### 场景 1: 默认配置

```bash
./compile.sh && ./package-rpm.sh
```

### 场景 2: 自定义安装路径

```bash
WORKSPACE_INSTALL_DIR="/opt/myapp" \
./compile.sh && ./package-rpm.sh
```

### 场景 3: 完全自定义

```bash
WORKSPACE_DIR="/src/app" \
WORKSPACE_INSTALL_DIR="/opt/app" \
WORKSPACE_VERSION="1.5.2" \
WORKSPACE_RELEASE="1" \
./compile.sh && ./package-rpm.sh
```

### 场景 4: 用户个人使用

```bash
WORKSPACE_INSTALL_DIR="$HOME/.local/tools" \
./compile.sh && ./package-rpm.sh
```

## 🧪 测试系统

```bash
./test-rpm-build.sh
```

## 📦 安装后的位置

### 默认安装

```
/opt/workspace/
├── bin/           # 二进制文件
├── apps/          # 应用数据
└── .rpm-info      # 安装信息

/usr/local/bin/*   # 符号链接
```

### 自定义安装

使用 `WORKSPACE_INSTALL_DIR=/custom/path` 时：

```
/custom/path/
├── bin/
├── apps/
└── .rpm-info

/usr/local/bin/*   # 符号链接
```

## 🔍 验证安装

```bash
# 检查包
rpm -qa | grep workspace-tools

# 列出文件
rpm -ql workspace-tools

# 查看信息
rpm -qi workspace-tools
```

## 🔄 升级/卸载

```bash
# 升级
sudo dnf upgrade workspace-tools-*.rpm

# 卸载
sudo dnf remove workspace-tools
```

## 🌟 核心特性

✅ **环境无关** - 不依赖固定路径或用户名
✅ **灵活配置** - 多种方式配置路径
✅ **多用户** - 支持多个用户同时使用
✅ **生产就绪** - 完整的打包、安装流程
✅ **向后兼容** - 可以直接使用无需修改

## 💡 提示

1. **测试环境**: 先运行 `./test-rpm-build.sh` 验证系统
2. **查看文档**: `cat QUICKSTART.md` 快速开始
3. **详细文档**: `cat README-RPM.md` 完整说明
4. **配置示例**: `cat CONFIG-EXAMPLES.md` 各种场景

## 📝 示例命令

### 基础

```bash
# 编译
./compile.sh

# 打包
./package-rpm.sh

# 安装
sudo dnf install rpmbuild/RPMS/noarch/workspace-tools-*.rpm
```

### 进阶

```bash
# 一行命令
WORKSPACE_INSTALL_DIR="/opt/myapp" ./compile.sh && ./package-rpm.sh

# 指定工作区
./compile.sh "/custom/path"

# 完全自定义
WORKSPACE_DIR="/src" \
WORKSPACE_INSTALL_DIR="/opt" \
WORKSPACE_VERSION="2.0" \
./compile.sh && ./package-rpm.sh
```

## 🎉 开始使用

```bash
# 1. 测试系统
./test-rpm-build.sh

# 2. 编译并打包
./compile.sh

# 3. 安装
sudo dnf install rpmbuild/RPMS/noarch/workspace-tools-*.rpm
```

---

**记住**: 所有路径都是动态配置的，不需要修改任何脚本代码！🚀
