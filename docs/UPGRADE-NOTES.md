# 升级说明 - 动态路径支持

## 🎉 重要更新

所有脚本现已支持**动态路径配置**，不再写死 `/home/sclead/workspace` 路径！

## ✨ 新特性

### 1. 动态路径支持

**之前**：
```bash
SOURCE_DIR="/home/sclead/workspace"  # 写死的路径
```

**现在**：
```bash
# 优先级: 环境变量 > 命令行参数 > 脚本所在目录
if [ -n "$WORKSPACE_DIR" ]; then
    SOURCE_DIR="$WORKSPACE_DIR"
elif [ -n "$1" ]; then
    SOURCE_DIR="$1"
else
    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
```

### 2. 自定义安装路径

```bash
# 默认: /opt/workspace
export WORKSPACE_INSTALL_DIR="/custom/path"
./package-rpm.sh
```

### 3. 多用户支持

每个用户可以独立构建和安装，无需担心路径冲突。

## 🔄 迁移指南

### 如果之前使用了固定路径

**旧方式**：
```bash
cd /home/sclead/workspace
./compile.sh
```

**新方式**（兼容）：
```bash
cd /home/sclead/workspace
./compile.sh  # 仍然可以正常工作
```

**新方式**（推荐 - 环境无关）：
```bash
cd /any/path/workspace
./compile.sh
```

### 如果需要指定不同的工作区

```bash
# 方式 1: 环境变量
export WORKSPACE_DIR="/custom/workspace"
./compile.sh

# 方式 2: 命令行参数
./compile.sh "/custom/workspace"
```

### 如果需要不同的安装路径

```bash
# 默认: /opt/workspace
./package-rpm.sh

# 自定义: /custom/install
export WORKSPACE_INSTALL_DIR="/custom/install"
./package-rpm.sh
```

## 📋 更新的文件

### 核心脚本

1. ✅ `compile.sh` - 添加了动态路径支持
2. ✅ `package-rpm.sh` - 添加了动态路径和安装路径支持
3. ✅ `workspace-tools.spec` - 添加了动态安装路径支持

### 文档

4. ✅ `README-RPM.md` - 更新了完整文档
5. ✅ `QUICKSTART.md` - 更新了快速开始指南
6. ✅ `CONFIG-EXAMPLES.md` - 新增配置示例
7. ✅ `RPM-PACKAGING-SUMMARY.md` - 更新了完整总结
8. ✅ `README-RPM-QUICK.md` - 新增快速参考
9. ✅ `test-rpm-build.sh` - 更新了测试脚本

## 🆕 新增文档

- `CONFIG-EXAMPLES.md` - 各种场景的配置示例
- `README-RPM-QUICK.md` - 快速参考卡片

## 🎯 兼容性

### 向后兼容

✅ **完全兼容旧的使用方式**

如果你之前在 `/home/sclead/workspace` 目录下使用脚本，**不需要做任何改变**，脚本仍然可以正常工作。

### 新功能

✅ **现在支持任意路径**

```bash
# 在任何目录下都可以使用
cd /any/path
./compile.sh
```

## 🚀 快速测试

### 测试系统

```bash
./test-rpm-build.sh
```

### 测试自定义路径

```bash
# 测试不同的工作区目录
./test-rpm-build.sh "/tmp/test-workspace"

# 测试不同的安装路径
WORKSPACE_INSTALL_DIR="/tmp/test-install" \
./test-rpm-build.sh
```

## 📊 环境变量参考

| 变量 | 说明 | 默认值 | 之前 |
|------|------|--------|------|
| `WORKSPACE_DIR` | 工作区目录 | 脚本所在目录 | `/home/sclead/workspace` |
| `WORKSPACE_INSTALL_DIR` | 安装路径 | `/opt/workspace` | `/home/sclead/workspace` |
| `WORKSPACE_VERSION` | 包版本 | `1.0.0` | `1.0.0` |
| `WORKSPACE_RELEASE` | 包发布号 | `1` | `1` |

## 💡 使用建议

### 开发环境

```bash
cd ~/dev/workspace
WORKSPACE_INSTALL_DIR="$HOME/.local/dev-tools" \
./compile.sh && ./package-rpm.sh
```

### 生产环境

```bash
cd /srv/app/workspace
WORKSPACE_INSTALL_DIR="/opt/prod-tools" \
WORKSPACE_VERSION="$(date +%Y.%m.%d)" \
./compile.sh && ./package-rpm.sh
```

### CI/CD

```bash
WORKSPACE_DIR="$CI_PROJECT_DIR" \
WORKSPACE_INSTALL_DIR="/usr/local/workspace" \
WORKSPACE_VERSION="$CI_COMMIT_TAG" \
./compile.sh && ./package-rpm.sh
```

## 🆘 常见问题

### Q: 我需要修改现有的使用方式吗？

A: 不需要！如果你在 `/home/sclead/workspace` 下使用，保持原样即可。

### Q: 可以在其他用户目录下使用吗？

A: 可以！任何用户在任何目录下都可以使用。

### Q: 如何确认使用的是新的动态路径版本？

A: 运行 `./test-rpm-build.sh`，会显示 "spec 文件支持动态路径"。

### Q: 旧的 RPM 包还能用吗？

A: 可以！升级脚本不会影响已安装的 RPM 包。

## 🎉 总结

| 特性 | 之前 | 现在 |
|------|------|------|
| 工作区目录 | 写死 `/home/sclead/workspace` | 动态（环境变量/参数/当前目录） |
| 安装路径 | 写死 `/home/sclead/workspace` | 可配置（默认 `/opt/workspace`） |
| 多用户 | ❌ 不支持 | ✅ 完全支持 |
| 环境无关 | ❌ 否 | ✅ 是 |
| 向后兼容 | - | ✅ 完全兼容 |

## 📚 进一步阅读

- 快速开始: `QUICKSTART.md`
- 完整文档: `README-RPM.md`
- 配置示例: `CONFIG-EXAMPLES.md`
- 快速参考: `README-RPM-QUICK.md`

---

**升级已完成！享受灵活的动态路径配置吧！** 🚀
