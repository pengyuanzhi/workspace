# RPM 打包使用说明

## 概述

本系统将编译后的二进制文件打包成 RPM 包，可以通过 `dnf` 命令安装到系统中。

**重要特性**：所有路径都是动态配置的，不依赖固定的用户名或目录。

## 工作流程

```
源代码 (编译) → 二进制文件 (打包) → RPM 包 (安装) → 系统可用
```

## 快速开始

### 方式一：一键编译并打包（默认路径）

```bash
cd /path/to/your/workspace
./compile.sh
# 当询问是否打包时，输入 y
```

### 方式二：分步执行

```bash
# 1. 编译源代码
./compile.sh

# 2. 打包成 RPM
./package-rpm.sh

# 3. 安装 RPM 包
sudo dnf install rpmbuild/RPMS/noarch/workspace-tools-*.rpm
```

## 配置选项

### 环境变量配置

可以通过环境变量自定义路径：

```bash
# 设置工作区目录
export WORKSPACE_DIR="/custom/workspace/path"
./compile.sh

# 设置安装路径（默认: /opt/workspace）
export WORKSPACE_INSTALL_DIR="/custom/install/path"
./package-rpm.sh

# 设置版本和发布号
export WORKSPACE_VERSION="2.0.0"
export WORKSPACE_RELEASE="1"
./package-rpm.sh
```

### 命令行参数

也可以通过命令行参数指定路径：

```bash
# 指定工作区目录
./compile.sh "/custom/workspace/path"

# 指定工作区目录（打包）
./package-rpm.sh "/custom/workspace/path"
```

### 默认路径

如果未指定，脚本使用以下默认值：

- **工作区目录**: 脚本所在的目录
- **安装路径**: `/opt/workspace`
- **二进制目录**: `/opt/workspace/bin`
- **应用目录**: `/opt/workspace/apps`
- **符号链接**: `/usr/local/bin/*`

## 文件说明

### 核心文件

- `compile.sh` - 编译脚本，将 .sh 和 .py 编译成二进制
- `package-rpm.sh` - 打包脚本，将二进制打包成 RPM
- `workspace-tools.spec` - RPM 规范文件

### 目录结构

```
/workspace/                           # 工作区根目录（动态）
├── compile.sh                        # 编译脚本
├── package-rpm.sh                   # 打包脚本
├── workspace-tools.spec             # RPM spec 文件
├── build/                            # 编译输出目录
│   ├── bin/                         # 二进制文件
│   └── apps/                        # 应用目录
└── rpmbuild/                        # RPM 构建目录
    ├── SOURCES/                     # 源码 tarball
    ├── SPECS/                       # spec 文件
    ├── BUILD/                       # 构建过程目录
    ├── RPMS/                        # 生成的 RPM 包
    └── SRPMS/                       # 源码 RPM 包
```

## 安装后的位置

安装 RPM 包后，文件会被放置在以下位置：

```
/opt/workspace/                      # 默认安装根目录
├── bin/                             # 二进制可执行文件
├── apps/                            # 应用数据
└── .rpm-info                        # 安装信息

/usr/local/bin/                      # 符号链接（指向 /opt/workspace/bin）
```

**自定义安装路径示例**：

如果使用 `WORKSPACE_INSTALL_DIR=/custom/path`，则安装位置为：

```
/custom/path/
├── bin/
├── apps/
└── .rpm-info

/usr/local/bin/                      # 符号链接（指向 /custom/path/bin）
```

## 升级和卸载

### 升级

```bash
sudo dnf upgrade workspace-tools-*.rpm
```

### 卸载

```bash
sudo dnf remove workspace-tools
```

**注意**：卸载会自动删除 `/usr/local/bin/` 中的符号链接，但保留 `/opt/workspace/` 中的文件（手动删除）。

## 自定义配置

### 修改包信息

编辑 `workspace-tools.spec` 文件：

```spec
Name:           workspace-tools      # 包名
Version:        %{workspace_version:1.0.0}   # 版本号（支持环境变量）
Release:        %{workspace_release:1}%{?dist} # 发行号（支持环境变量）
Summary:        工作区工具集           # 描述
```

### 修改安装路径

有三种方式修改安装路径：

**方式一：环境变量（推荐）**

```bash
export WORKSPACE_INSTALL_DIR="/custom/install/path"
./package-rpm.sh
```

**方式二：RPM macro（构建时）**

```bash
rpmbuild -ba \
  --define "install_dir /custom/install/path" \
  workspace-tools.spec
```

**方式三：修改 spec 文件**

```spec
%global install_dir /custom/install/path
```

## 多用户支持

本系统完全支持多用户场景，每个用户可以：

1. **独立的工作区目录**：每个用户在自己的目录下运行脚本
2. **不同的安装路径**：通过 `WORKSPACE_INSTALL_DIR` 指定不同的安装位置
3. **独立的 RPM 包**：每个用户可以构建自己的 RPM 包

**示例**：

```bash
# 用户 A
/home/usera/workspace:
  WORKSPACE_DIR=/home/usera/workspace \
  WORKSPACE_INSTALL_DIR=/home/usera/tools \
  ./compile.sh && ./package-rpm.sh

# 用户 B
/home/userb/workspace:
  WORKSPACE_DIR=/home/userb/workspace \
  WORKSPACE_INSTALL_DIR=/home/userb/tools \
  ./compile.sh && ./package-rpm.sh
```

## 故障排除

### rpmbuild 未安装

```bash
sudo dnf install rpm-build
```

### 权限问题

确保脚本有执行权限：

```bash
chmod +x compile.sh
chmod +x package-rpm.sh
```

### 路径问题

如果遇到路径相关的错误，检查：

1. 工作区目录是否正确：`echo $WORKSPACE_DIR`
2. 安装路径是否正确：`echo $WORKSPACE_INSTALL_DIR`
3. 当前工作目录是否正确：`pwd`

### 构建失败

检查构建日志：

```bash
# 查看构建目录
ls -la rpmbuild/BUILD/

# 查看错误日志
cat rpmbuild/BUILD/*.log
```

### 符号链接问题

如果工具无法直接使用，检查符号链接：

```bash
ls -la /usr/local/bin/ | grep workspace
```

如果符号链接不存在，手动创建：

```bash
sudo ln -sf /opt/workspace/bin/toolname /usr/local/bin/toolname
```

## 高级用法

### 创建本地 RPM 仓库

如果需要在多台机器上安装，可以创建本地 RPM 仓库：

```bash
# 1. 安装 createrepo
sudo dnf install createrepo

# 2. 创建仓库目录
sudo mkdir -p /var/local-repo/Packages
sudo cp rpmbuild/RPMS/noarch/*.rpm /var/local-repo/Packages/

# 3. 生成仓库元数据
cd /var/local-repo
sudo createrepo .

# 4. 添加仓库
echo "[local-repo]
name=Local Repository
baseurl=file:///var/local-repo
enabled=1
gpgcheck=0" | sudo tee /etc/yum.repos.d/local.repo

# 5. 安装
sudo dnf install workspace-tools
```

### 签名 RPM 包（可选）

```bash
# 1. 生成 GPG 密钥
gpg --gen-key

# 2. 签名 RPM
rpm --addsign rpmbuild/RPMS/noarch/*.rpm

# 3. 导出公钥
rpm --export /path/to/key > RPM-GPG-KEY-workspace-tools

# 4. 在 spec 文件中启用签名验证
%{?gpg_verify: %{?gpg_verify}}
```

### Docker 容器内使用

在 Docker 容器中使用时，需要注意：

```dockerfile
FROM fedora:latest

# 安装必要工具
RUN dnf install -y rpm-build python3 bash

# 设置工作区目录
WORKDIR /workspace

# 复制脚本
COPY compile.sh package-rpm.sh workspace-tools.spec /workspace/

# 构建并打包
RUN ./compile.sh && \
    WORKSPACE_INSTALL_DIR=/usr/local/workspace ./package-rpm.sh
```

## 常见问题

### Q: 我可以更改安装路径吗？
A: 可以！使用 `WORKSPACE_INSTALL_DIR` 环境变量，例如：
```bash
WORKSPACE_INSTALL_DIR=/custom/path ./package-rpm.sh
```

### Q: 多个用户可以同时使用吗？
A: 可以！每个用户在自己的目录下运行脚本，并指定不同的安装路径。

### Q: 符号链接在哪里？
A: 默认在 `/usr/local/bin/`，指向安装目录的 `bin/` 子目录。

### Q: 如何验证安装成功？
A: 运行以下命令：
```bash
rpm -qa | grep workspace-tools
rpm -ql workspace-tools
```

### Q: 卸载后会删除所有文件吗？
A: 卸载会删除符号链接，但安装目录中的文件需要手动删除。

## 许可证

本工具包采用专有许可证。

## 支持

如有问题，请检查构建日志或联系维护人员。

## 版本历史

- **1.0.0** - 初始版本
  - 支持动态路径配置
  - 支持多用户环境
  - 支持自定义安装路径
