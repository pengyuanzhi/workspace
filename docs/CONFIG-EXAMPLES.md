# 配置示例

## 基础使用

### 默认配置（最简单）

```bash
cd /any/path/workspace
./compile.sh
```

使用默认值：
- 工作区目录: 当前目录（脚本所在位置）
- 安装路径: `/opt/workspace`

## 不同用户场景

### 用户个人使用

```bash
# 在用户主目录下
cd ~/myproject

# 安装到用户目录
WORKSPACE_INSTALL_DIR="$HOME/.local/mytools" \
./compile.sh && ./package-rpm.sh

# 或使用完整路径
WORKSPACE_INSTALL_DIR="/home/username/tools" \
./compile.sh && ./package-rpm.sh
```

### 服务器环境

```bash
# 系统级应用
cd /srv/application

# 安装到 /opt
WORKSPACE_INSTALL_DIR="/opt/myapp" \
./compile.sh && ./package-rpm.sh
```

### 开发环境

```bash
# 开发分支
cd /workspace/dev-branch

# 安装到开发目录
WORKSPACE_INSTALL_DIR="/opt/dev-tools" \
WORKSPACE_VERSION="1.0.0-dev" \
./compile.sh && ./package-rpm.sh
```

### 生产环境

```bash
# 生产分支
cd /workspace/prod-branch

# 安装到生产目录
WORKSPACE_INSTALL_DIR="/opt/prod-tools" \
WORKSPACE_VERSION="2.1.0" \
WORKSPACE_RELEASE="1" \
./compile.sh && ./package-rpm.sh
```

## 多环境配置

### 开发/测试/生产环境

```bash
# 开发环境
WORKSPACE_DIR="/workspace/dev" \
WORKSPACE_INSTALL_DIR="/opt/dev-tools" \
WORKSPACE_VERSION="1.0.0-dev" \
./compile.sh && ./package-rpm.sh

# 测试环境
WORKSPACE_DIR="/workspace/test" \
WORKSPACE_INSTALL_DIR="/opt/test-tools" \
WORKSPACE_VERSION="1.0.0-rc1" \
./compile.sh && ./package-rpm.sh

# 生产环境
WORKSPACE_DIR="/workspace/prod" \
WORKSPACE_INSTALL_DIR="/opt/prod-tools" \
WORKSPACE_VERSION="1.0.0" \
WORKSPACE_COMPILE_AND_PACKAGE
```

### 基于环境的配置脚本

```bash
#!/bin/bash
# deploy.sh - 环境部署脚本

ENV="${1:-dev}"

case "$ENV" in
    dev)
        WORKSPACE_DIR="/workspace/dev"
        WORKSPACE_INSTALL_DIR="/opt/dev-tools"
        WORKSPACE_VERSION="1.0.0-dev"
        ;;
    test)
        WORKSPACE_DIR="/workspace/test"
        WORKSPACE_INSTALL_DIR="/opt/test-tools"
        WORKSPACE_VERSION="1.0.0-rc1"
        ;;
    prod)
        WORKSPACE_DIR="/workspace/prod"
        WORKSPACE_INSTALL_DIR="/opt/prod-tools"
        WORKSPACE_VERSION="1.0.0"
        ;;
    *)
        echo "Usage: $0 [dev|test|prod]"
        exit 1
        ;;
esac

export WORKSPACE_DIR WORKSPACE_INSTALL_DIR WORKSPACE_VERSION

cd "$WORKSPACE_DIR"
./compile.sh && ./package-rpm.sh

echo "部署完成: $ENV 环境"
echo "安装路径: $WORKSPACE_INSTALL_DIR"
```

使用：
```bash
./deploy.sh dev    # 开发环境
./deploy.sh test   # 测试环境
./deploy.sh prod   # 生产环境
```

## CI/CD 集成

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build
  - package
  - deploy

variables:
  WORKSPACE_INSTALL_DIR: "/usr/local/workspace"

build:
  stage: build
  script:
    - export WORKSPACE_DIR="$CI_PROJECT_DIR"
    - export WORKSPACE_VERSION="$CI_COMMIT_TAG"
    - ./compile.sh
  artifacts:
    paths:
      - build/

package:
  stage: package
  needs: [build]
  script:
    - export WORKSPACE_DIR="$CI_PROJECT_DIR"
    - export WORKSPACE_VERSION="$CI_COMMIT_TAG"
    - ./package-rpm.sh
  artifacts:
    paths:
      - rpmbuild/RPMS/
    expire_in: 1 week

deploy:
  stage: deploy
  needs: [package]
  script:
    - sudo dnf install -y rpmbuild/RPMS/noarch/workspace-tools-*.rpm
  only:
    - tags
```

### GitHub Actions

```yaml
# .github/workflows/build.yml
name: Build and Package

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    runs-on: fedora-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set environment
        run: |
          echo "WORKSPACE_DIR=$GITHUB_WORKSPACE" >> $GITHUB_ENV
          echo "WORKSPACE_VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_ENV

      - name: Install dependencies
        run: |
          sudo dnf install -y rpm-build python3 bash

      - name: Compile
        run: ./compile.sh

      - name: Package
        run: ./package-rpm.sh

      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: rpm-package
          path: rpmbuild/RPMS/noarch/*.rpm
```

### Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        WORKSPACE_DIR = "${WORKSPACE}"
        WORKSPACE_INSTALL_DIR = "/usr/local/workspace"
        WORKSPACE_VERSION = "${env.BUILD_TAG}"
    }

    stages {
        stage('Build') {
            steps {
                sh """
                    export WORKSPACE_DIR=\${WORKSPACE_DIR}
                    export WORKSPACE_INSTALL_DIR=\${WORKSPACE_INSTALL_DIR}
                    export WORKSPACE_VERSION=\${WORKSPACE_VERSION}
                    ./compile.sh
                """
            }
        }

        stage('Package') {
            steps {
                sh """
                    export WORKSPACE_DIR=\${WORKSPACE_DIR}
                    export WORKSPACE_INSTALL_DIR=\${WORKSPACE_INSTALL_DIR}
                    export WORKSPACE_VERSION=\${WORKSPACE_VERSION}
                    ./package-rpm.sh
                """
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'sudo dnf install -y rpmbuild/RPMS/noarch/*.rpm'
            }
        }
    }
}
```

## Docker 容器

### 基础 Dockerfile

```dockerfile
# Dockerfile
FROM fedora:latest

# 安装必要工具
RUN dnf install -y rpm-build python3 bash

# 设置环境变量
ENV WORKSPACE_INSTALL_DIR=/usr/local/workspace

# 复制源代码
COPY . /workspace

WORKDIR /workspace

# 编译和打包
RUN ./compile.sh && ./package-rpm.sh

# 安装
RUN dnf install -y rpmbuild/RPMS/noarch/workspace-tools-*.rpm

# 清理
RUN rm -rf build rpmbuild

# 设置入口点
ENTRYPOINT ["/usr/local/workspace/bin/your-tool"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  builder:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - WORKSPACE_INSTALL_DIR=/opt/workspace
      - WORKSPACE_VERSION=1.0.0
    volumes:
      - ./output:/workspace/rpmbuild/RPMS
```

## 多项目配置

### 项目 A

```bash
cd /projects/project-a
WORKSPACE_INSTALL_DIR="/opt/project-a" \
WORKSPACE_VERSION="1.2.3" \
./compile.sh && ./package-rpm.sh
```

### 项目 B

```bash
cd /projects/project-b
WORKSPACE_INSTALL_DIR="/opt/project-b" \
WORKSPACE_VERSION="2.1.4" \
./compile.sh && ./package-rpm.sh
```

### 项目管理脚本

```bash
#!/bin/bash
# build-all.sh - 批量构建多个项目

PROJECTS=(
    "project-a:/opt/project-a:1.2.3"
    "project-b:/opt/project-b:2.1.4"
    "project-c:/opt/project-c:3.0.1"
)

for project in "${PROJECTS[@]}"; do
    IFS=':' read -r name install version <<< "$project"

    echo "Building $name..."

    cd "/projects/$name" || continue

    WORKSPACE_INSTALL_DIR="$install" \
    WORKSPACE_VERSION="$version" \
    ./compile.sh && ./package-rpm.sh

    echo "✓ $name built successfully"
    echo ""
done
```

## 版本管理

### Git Tag 版本

```bash
# 创建 git tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# 使用 git tag 作为版本号
WORKSPACE_VERSION="$(git describe --tags --always)" \
./compile.sh && ./package-rpm.sh
```

### 日期时间版本

```bash
# 使用日期时间作为版本号
WORKSPACE_VERSION="$(date +%Y.%m.%d)" \
WORKSPACE_RELEASE="$(date +%H%M%S)" \
./compile.sh && ./package-rpm.sh
```

### 自动递增版本

```bash
#!/bin/bash
# next-version.sh - 自动递增版本号

VERSION_FILE="version.txt"

if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
else
    CURRENT_VERSION="1.0.0"
fi

# 拆分版本号
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"

# 递增补丁版本
((patch++))

NEW_VERSION="${major}.${minor}.${patch}"

# 保存新版本号
echo "$NEW_VERSION" > "$VERSION_FILE"

echo "New version: $NEW_VERSION"
```

使用：
```bash
NEW_VERSION=$(./next-version.sh)
WORKSPACE_VERSION="$NEW_VERSION" \
./compile.sh && ./package-rpm.sh
```

## 高级技巧

### 配置文件

创建 `.rpmscript.conf`：

```bash
# .rpmscript.conf
WORKSPACE_DIR="/custom/workspace"
WORKSPACE_INSTALL_DIR="/custom/install"
WORKSPACE_VERSION="1.0.0"
WORKSPACE_RELEASE="1"
```

使用：

```bash
#!/bin/bash
# 使用配置文件

CONFIG_FILE=".rpmscript.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    export WORKSPACE_DIR WORKSPACE_INSTALL_DIR WORKSPACE_VERSION WORKSPACE_RELEASE
    echo "已加载配置: $CONFIG_FILE"
fi

./compile.sh && ./package-rpm.sh
```

### 条件编译

```bash
#!/bin/bash
# 条件编译脚本

USE_PYINSTALLER="${USE_PYINSTALLER:-true}"
USE_SHC="${USE_SHC:-true}"

export USE_PYINSTALLER USE_SHC

if [ "$USE_PYINSTALLER" = "true" ]; then
    echo "使用 PyInstaller 编译 Python"
else
    echo "使用字节码编译 Python"
fi

if [ "$USE_SHC" = "true" ]; then
    echo "使用 shc 编译 Bash"
else
    echo "保留 Bash 源码"
fi

./compile.sh
```

使用：

```bash
# 使用 PyInstaller 和 shc
./compile-with-options.sh

# 只使用 PyInstaller
USE_SHC=false ./compile-with-options.sh

# 使用字节码和源码
USE_PYINSTALLER=false USE_SHC=false ./compile-with-options.sh
```

## 故障排查

### 检查当前配置

```bash
#!/bin/bash
# check-config.sh

echo "当前配置："
echo "工作区目录: ${WORKSPACE_DIR:-$(pwd)}"
echo "安装路径: ${WORKSPACE_INSTALL_DIR:-/opt/workspace}"
echo "版本: ${WORKSPACE_VERSION:-1.0.0}"
echo "发布号: ${WORKSPACE_RELEASE:-1}"
echo ""

echo "环境变量："
env | grep WORKSPACE
```

### 重置为默认值

```bash
# 清除所有自定义环境变量
unset WORKSPACE_DIR
unset WORKSPACE_INSTALL_DIR
unset WORKSPACE_VERSION
unset WORKSPACE_RELEASE

# 使用默认配置
./compile.sh && ./package-rpm.sh
```

---

选择适合你的配置方式，开始使用吧！🚀
