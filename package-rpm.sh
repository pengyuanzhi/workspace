#!/bin/bash

# RPM 打包脚本 - 将编译后的二进制打包成 RPM 包

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 配置
# 优先级: 环境变量 > 命令行参数 > 脚本所在目录
if [ -n "$WORKSPACE_DIR" ]; then
    SOURCE_DIR="$WORKSPACE_DIR"
elif [ -n "$1" ]; then
    SOURCE_DIR="$1"
else
    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

BUILD_DIR="${SOURCE_DIR}/build"
RPM_BUILD_DIR="${SOURCE_DIR}/rpmbuild"
SPEC_FILE="${SOURCE_DIR}/workspace-tools.spec"
PACKAGE_NAME="workspace-tools"
VERSION="${WORKSPACE_VERSION:-1.0.0}"
RELEASE="${WORKSPACE_RELEASE:-1}"

# 安装路径（可通过环境变量覆盖）
WORKSPACE_INSTALL_DIR="${WORKSPACE_INSTALL_DIR:-/opt/workspace}"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}RPM 打包脚本${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "源目录: ${SOURCE_DIR}"
echo "构建目录: ${BUILD_DIR}"
echo "RPM 构建目录: ${RPM_BUILD_DIR}"
echo "安装路径: ${WORKSPACE_INSTALL_DIR}"
echo "包版本: ${VERSION}-${RELEASE}"
echo ""

# 显示环境变量提示
if [ -n "$WORKSPACE_DIR" ]; then
    echo -e "${YELLOW}使用自定义工作区目录: ${WORKSPACE_DIR}${NC}"
fi
if [ -n "$WORKSPACE_INSTALL_DIR" ]; then
    echo -e "${YELLOW}使用自定义安装路径: ${WORKSPACE_INSTALL_DIR}${NC}"
fi
echo ""

# 检查是否已编译
if [ ! -d "$BUILD_DIR" ] || [ -z "$(find "$BUILD_DIR" -type f -executable 2>/dev/null | head -1)" ]; then
    echo -e "${YELLOW}⚠ 未找到编译的二进制文件${NC}"
    echo -e "${YELLOW}先运行 ./compile.sh 进行编译${NC}"
    read -p "是否现在运行编译? \(y/N\): " compile_now
    if [[ "$compile_now" =~ ^[Yy]$ ]]; then
        echo ""
        ./compile.sh
    else
        exit 1
    fi
fi

# 步骤 1: 检查 rpmbuild
echo -e "${BLUE}[1/6] 检查构建工具...${NC}"

if ! command -v rpmbuild >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ rpmbuild 未安装${NC}"
    echo "安装 rpm-build 包..."
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y rpm-build
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y rpm-build
    else
        echo -e "${RED}✗ 无法安装 rpmbuild${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ rpmbuild 已安装${NC}"
else
    echo -e "${GREEN}✓ rpmbuild 已安装${NC}"
fi

echo ""

# 步骤 2: 准备 rpmbuild 目录结构
echo -e "${BLUE}[2/6] 准备 rpmbuild 目录结构...${NC}"

mkdir -p "${RPM_BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
echo -e "${GREEN}✓ 目录结构已创建${NC}"

echo ""

# 步骤 3: 检查并清理已存在的安装目录
echo -e "${BLUE}[3/6] 检查并清理已存在的安装目录...${NC}"

if [ -d "${WORKSPACE_INSTALL_DIR}" ]; then
    echo -e "${YELLOW}⚠ 检测到已存在的安装目录: ${WORKSPACE_INSTALL_DIR}${NC}"
    echo -e "${YELLOW}⚠ 构建前将清理该目录以避免冲突${NC}"
    echo ""
    read -p "是否继续? \(y/N\): " confirm_clean
    if [[ "$confirm_clean" =~ ^[Yy]$ ]]; then
        echo "正在清理..."
        sudo rm -rf "${WORKSPACE_INSTALL_DIR}"
        echo -e "${GREEN}✓ 已清理: ${WORKSPACE_INSTALL_DIR}${NC}"
    else
        echo -e "${RED}✗ 用户取消操作${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ 安装目录不存在，无需清理${NC}"
fi

echo ""

# 步骤 4: 创建源码 tarball
echo -e "${BLUE}[4/6] 创建源码 tarball...${NC}"

# 创建临时目录用于打包
TEMP_DIR="${RPM_BUILD_DIR}/temp/${PACKAGE_NAME}-${VERSION}"
mkdir -p "$TEMP_DIR"

# 创建 bin 和 apps 目录
mkdir -p "$TEMP_DIR/bin"
mkdir -p "$TEMP_DIR/apps"

# 复制构建的二进制文件到 bin 目录
if [ -d "${BUILD_DIR}/bin" ]; then
    cp -r "${BUILD_DIR}/bin"/* "$TEMP_DIR/bin/" 2>/dev/null || true
    echo -e "  ${GREEN}✓ 已复制: bin/ 中的文件${NC}"
else
    # 如果没有 bin 目录，则将可执行文件复制到 bin/
    find "$BUILD_DIR" -maxdepth 1 -type f -executable -not -name "*.sh" -exec cp {} "$TEMP_DIR/bin/" \;
    EXE_COUNT=$(find "$TEMP_DIR/bin" -type f | wc -l)
    if [ "$EXE_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓ 已复制 $EXE_COUNT 个可执行文件到 bin/${NC}"
    fi
fi

# 复制 apps 目录
if [ -d "${BUILD_DIR}/apps" ]; then
    cp -r "${BUILD_DIR}/apps"/* "$TEMP_DIR/apps/" 2>/dev/null || true
    echo -e "  ${GREEN}✓ 已复制: apps/ 中的文件${NC}"
elif [ -d "${SOURCE_DIR}/apps" ]; then
    # 如果 build 中没有 apps，尝试从源代码复制
    cp -r "${SOURCE_DIR}/apps"/* "$TEMP_DIR/apps/" 2>/dev/null || true
    echo -e "  ${GREEN}✓ 已复制: apps/ 中的文件（从源代码）${NC}"
fi

# 复制配置文件
if [ -f "${BUILD_DIR}/workspace.conf" ]; then
    cp "${BUILD_DIR}/workspace.conf" "$TEMP_DIR/"
    echo -e "  ${GREEN}✓ 已复制: workspace.conf${NC}"
elif [ -f "${SOURCE_DIR}/workspace.conf" ]; then
    cp "${SOURCE_DIR}/workspace.conf" "$TEMP_DIR/"
    echo -e "  ${GREEN}✓ 已复制: workspace.conf（从源代码）${NC}"
fi

# 创建 tarball
cd "${RPM_BUILD_DIR}/temp"
tar -czf "${RPM_BUILD_DIR}/SOURCES/${PACKAGE_NAME}-${VERSION}.tar.gz" "${PACKAGE_NAME}-${VERSION}"

# 清理临时目录
rm -rf "${RPM_BUILD_DIR}/temp"

echo -e "${GREEN}✓ 源码 tarball 已创建${NC}"
echo ""

# 步骤 5: 复制 spec 文件
echo -e "${BLUE}[5/6] 复制 spec 文件...${NC}"

cp "$SPEC_FILE" "${RPM_BUILD_DIR}/SPECS/"
echo -e "${GREEN}✓ spec 文件已复制${NC}"

echo ""

# 步骤 6: 构建 RPM
echo -e "${BLUE}[6/6] 构建 RPM 包...${NC}"
echo -e "安装路径: ${WORKSPACE_INSTALL_DIR}"
echo ""

cd "${RPM_BUILD_DIR}/SPECS"
rpmbuild -ba \
    --define "_topdir ${RPM_BUILD_DIR}" \
    --define "install_dir ${WORKSPACE_INSTALL_DIR}" \
    --define "workspace_version ${VERSION}" \
    --define "workspace_release ${RELEASE}" \
    "${PACKAGE_NAME}.spec"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ RPM 构建成功${NC}"
    echo ""

    # 查找生成的 RPM 包
    RPM_FILE=$(find "${RPM_BUILD_DIR}/RPMS" -name "${PACKAGE_NAME}*.rpm" | head -1)

    if [ -n "$RPM_FILE" ]; then
        RPM_SIZE=$(du -h "$RPM_FILE" | cut -f1)
        RPM_NAME=$(basename "$RPM_FILE")
        echo -e "${BLUE}=========================================${NC}"
        echo -e "${BLUE}RPM 包已生成${NC}"
        echo -e "${BLUE}=========================================${NC}"
        echo ""
        echo "包名: ${RPM_NAME}"
        echo "路径: ${RPM_FILE}"
        echo "大小: ${RPM_SIZE}"
        echo ""
        echo -e "${BLUE}安装命令:${NC}"
        echo "  sudo dnf install ${RPM_FILE}"
        echo ""
        echo -e "${BLUE}或复制到仓库后:${NC}"
        echo "  sudo dnf install ${PACKAGE_NAME}"
        echo ""
    else
        echo -e "${RED}✗ 未找到 RPM 文件${NC}"
        exit 1
    fi
else
    echo ""
    echo -e "${RED}✗ RPM 构建失败${NC}"
    echo "检查日志: ${RPM_BUILD_DIR}/BUILD"
    exit 1
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}打包完成！${NC}"
echo -e "${BLUE}=========================================${NC}"
