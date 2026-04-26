# 快速开始指南

## 环境无关使用

本系统完全支持任意用户和路径，不需要写死用户名或目录。

## 一键流程（推荐）

```bash
cd /path/to/your/workspace
./compile.sh
```

当脚本询问"是否立即打包成 RPM 包?"时，输入 `y`。

然后当询问"是否立即安装此 RPM 包?"时，输入 `y`。

完成！你现在可以在系统的任何地方使用这些工具了。

## 分步流程

### 1️⃣ 编译源代码

```bash
# 使用当前目录作为工作区
./compile.sh

# 或者指定工作区目录
./compile.sh "/custom/workspace/path"

# 或者使用环境变量
export WORKSPACE_DIR="/custom/workspace/path"
./compile.sh
```

这会编译所有 `.sh` 和 `.py` 文件到 `build/` 目录。

### 2️⃣ 打包成 RPM

```bash
# 使用默认安装路径 (/opt/workspace)
./package-rpm.sh

# 或者指定工作区目录
./package-rpm.sh "/custom/workspace/path"

# 或者指定自定义安装路径
export WORKSPACE_INSTALL_DIR="/custom/install/path"
./package-rpm.sh
```

这会创建一个可通过 `dnf` 安装的 RPM 包。

### 3️⃣ 安装 RPM

```bash
# 安装生成的 RPM 包
sudo dnf install rpmbuild/RPMS/noarch/workspace-tools-*.rpm
```

安装完成后，工具会自动链接到 `/usr/local/bin/`，可以直接使用。

## 路径配置

### 默认路径

如果未指定任何配置：

```
工作区目录: 脚本所在的目录
安装路径:   /opt/workspace
符号链接:   /usr/local/bin/*
```

### 自定义路径

#### 选项 1: 环境变量（推荐）

```bash
# 设置工作区目录
export WORKSPACE_DIR="/my/workspace"
./compile.sh

# 设置安装路径
export WORKSPACE_INSTALL_DIR="/my/tools"
./package-rpm.sh
```

#### 选项 2: 命令行参数

```bash
# 指定工作区目录
./compile.sh "/my/workspace"

# 指定工作区目录（打包）
./package-rpm.sh "/my/workspace"
```

#### 选项 3: 一行命令

```bash
WORKSPACE_DIR="/my/workspace" \
WORKSPACE_INSTALL_DIR="/my/tools" \
./compile.sh && ./package-rpm.sh
```

## 验证安装

```bash
# 检查安装的包
rpm -qa | grep workspace-tools

# 列出安装的文件
rpm -ql workspace-tools

# 查看安装信息
cat /opt/workspace/.rpm-info  # 或自定义的安装路径

# 测试工具（根据实际工具名称）
toolname --help
```

## 常用命令

### 只编译，不打包
```bash
./compile.sh
# 当询问是否打包时，输入 N
```

### 只打包（需要先编译）
```bash
./package-rpm.sh
```

### 重新编译和打包
```bash
./compile.sh          # 重新编译
./package-rpm.sh      # 重新打包
```

### 使用不同路径
```bash
# 用户 A 的设置
WORKSPACE_DIR="/home/usera/workspace" \
WORKSPACE_INSTALL_DIR="/home/usera/tools" \
./compile.sh && ./package-rpm.sh

# 用户 B 的设置
WORKSPACE_DIR="/home/userb/workspace" \
WORKSPACE_INSTALL_DIR="/home/userb/tools" \
./compile.sh && ./package-rpm.sh
```

## 卸载

```bash
sudo dnf remove workspace-tools

# 可选：手动删除安装目录
sudo rm -rf /opt/workspace  # 或你的自定义安装路径
```

## 下一步

- 详细说明请查看 [README-RPM.md](README-RPM.md)
- 运行测试验证系统：`./test-rpm-build.sh`

## 示例场景

### 场景 1: 服务器管理员

```bash
# 在 /srv/workspace 下工作
cd /srv/workspace
./compile.sh && ./package-rpm.sh

# 安装到 /usr/local/workspace
export WORKSPACE_INSTALL_DIR="/usr/local/workspace"
./package-rpm.sh

# 分发给其他服务器
sudo dnf install rpmbuild/RPMS/noarch/workspace-tools-*.rpm
```

### 场景 2: 开发者个人使用

```bash
# 在用户主目录下工作
cd ~/my-project/workspace
./compile.sh && ./package-rpm.sh

# 安装到个人目录
export WORKSPACE_INSTALL_DIR="$HOME/tools"
./package-rpm.sh
```

### 场景 3: CI/CD 流水线

```bash
#!/bin/bash
# CI/CD 脚本

WORKSPACE_DIR="$CI_PROJECT_DIR"
WORKSPACE_INSTALL_DIR="/opt/ci-tools"
WORKSPACE_VERSION="$CI_COMMIT_TAG"

export WORKSPACE_DIR WORKSPACE_INSTALL_DIR WORKSPACE_VERSION

cd "$WORKSPACE_DIR"
./compile.sh && ./package-rpm.sh

# 上传到包仓库
curl -X POST "$PACKAGE_REPO_URL" \
  -F "file=@rpmbuild/RPMS/noarch/workspace-tools-*.rpm"
```

### 场景 4: Docker 容器

```dockerfile
FROM fedora:latest

RUN dnf install -y rpm-build python3 bash

WORKDIR /workspace
COPY . /workspace/

ENV WORKSPACE_INSTALL_DIR=/usr/local/workspace

RUN ./compile.sh && ./package-rpm.sh && \
    dnf install -y rpmbuild/RPMS/noarch/workspace-tools-*.rpm
```

## 快速参考

| 环境变量 | 说明 | 默认值 |
|---------|------|--------|
| `WORKSPACE_DIR` | 工作区目录 | 脚本所在目录 |
| `WORKSPACE_INSTALL_DIR` | 安装路径 | `/opt/workspace` |
| `WORKSPACE_VERSION` | 包版本 | `1.0.0` |
| `WORKSPACE_RELEASE` | 包发布号 | `1` |

## 故障排除

### 路径错误

```bash
# 检查当前配置
echo "工作区: ${WORKSPACE_DIR:-$(pwd)}"
echo "安装: ${WORKSPACE_INSTALL_DIR:-/opt/workspace}"
```

### 权限错误

```bash
# 确保脚本有执行权限
chmod +x compile.sh package-rpm.sh
```

### 安装失败

```bash
# 检查 RPM 包内容
rpm -qpl rpmbuild/RPMS/noarch/workspace-tools-*.rpm

# 查看依赖
rpm -qpR rpmbuild/RPMS/noarch/workspace-tools-*.rpm
```

---

需要更多帮助？查看 [README-RPM.md](README-RPM.md) 获取详细文档。
