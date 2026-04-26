#!/bin/bash

# RPM 打包系统测试脚本

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 动态获取源目录
if [ -n "$WORKSPACE_DIR" ]; then
    SOURCE_DIR="$WORKSPACE_DIR"
elif [ -n "$1" ]; then
    SOURCE_DIR="$1"
else
    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 安装路径（可通过环境变量覆盖）
WORKSPACE_INSTALL_DIR="${WORKSPACE_INSTALL_DIR:-/opt/workspace}"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}RPM 打包系统测试${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "工作区目录: ${SOURCE_DIR}"
echo "安装路径: ${WORKSPACE_INSTALL_DIR}"
echo ""

# 测试 1: 检查依赖
echo -e "${BLUE}[测试 1/5] 检查构建工具...${NC}"
if command -v rpmbuild >/dev/null 2>&1; then
    echo -e "${GREEN}✓ rpmbuild 已安装${NC}"
else
    echo -e "${RED}✗ rpmbuild 未安装${NC}"
    echo "运行: sudo dnf install rpm-build"
    exit 1
fi

if command -v python3 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ python3 已安装${NC}"
else
    echo -e "${RED}✗ python3 未安装${NC}"
    exit 1
fi

echo ""

# 测试 2: 检查脚本文件
echo -e "${BLUE}[测试 2/5] 检查脚本文件...${NC}"

SCRIPTS=(
    "compile.sh"
    "package-rpm.sh"
    "workspace-tools.spec"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "${SOURCE_DIR}/${script}" ]; then
        echo -e "${GREEN}✓ ${script} 存在${NC}"
        if [ -x "${SOURCE_DIR}/${script}" ]; then
            echo -e "  ${GREEN}✓ 可执行${NC}"
        else
            chmod +x "${SOURCE_DIR}/${script}"
            echo -e "  ${YELLOW}⚠ 已添加执行权限${NC}"
        fi
    else
        echo -e "${RED}✗ ${script} 不存在${NC}"
        exit 1
    fi
done

echo ""

# 测试 3: 检查源代码
echo -e "${BLUE}[测试 3/5] 检查源代码...${NC}"

SH_COUNT=$(find "${SOURCE_DIR}" -maxdepth 1 -name "*.sh" -not -name "compile.sh" -not -name "package-rpm.sh" -not -name "install.sh" -not -name "test-*.sh" | wc -l)
PY_COUNT=$(find "${SOURCE_DIR}" -maxdepth 1 -name "*.py" | wc -l)

echo -e "找到 ${SH_COUNT} 个 Bash 脚本（排除编译脚本）"
echo -e "找到 ${PY_COUNT} 个 Python 脚本"

if [ $SH_COUNT -eq 0 ] && [ $PY_COUNT -eq 0 ]; then
    echo -e "${YELLOW}⚠ 未找到需要编译的源代码${NC}"
else
    echo -e "${GREEN}✓ 源代码正常${NC}"
fi

echo ""

# 测试 4: 验证 spec 文件
echo -e "${BLUE}[测试 4/5] 验证 spec 文件...${NC}"

SPEC_FILE="${SOURCE_DIR}/workspace-tools.spec"
if grep -q "Name:" "$SPEC_FILE" && \
   grep -q "Version:" "$SPEC_FILE" && \
   grep -q "Summary:" "$SPEC_FILE" && \
   grep -q "%description" "$SPEC_FILE" && \
   grep -q "%prep" "$SPEC_FILE" && \
   grep -q "%build" "$SPEC_FILE" && \
   grep -q "%install" "$SPEC_FILE" && \
   grep -q "%files" "$SPEC_FILE"; then
    echo -e "${GREEN}✓ spec 文件格式正确${NC}"
else
    echo -e "${RED}✗ spec 文件格式不正确${NC}"
    exit 1
fi

# 检查是否支持动态路径
if grep -q "install_dir" "$SPEC_FILE"; then
    echo -e "${GREEN}✓ spec 文件支持动态路径${NC}"
else
    echo -e "${YELLOW}⚠ spec 文件可能不支持动态路径${NC}"
fi

echo ""

# 测试 5: 模拟构建流程（不实际编译）
echo -e "${BLUE}[测试 5/5] 模拟构建流程...${NC}"

RPM_BUILD_DIR="${SOURCE_DIR}/rpmbuild"
mkdir -p "${RPM_BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
echo -e "${GREEN}✓ 目录结构已创建${NC}"

# 创建测试 tarball
TEMP_DIR="${RPM_BUILD_DIR}/temp/workspace-tools-1.0.0"
mkdir -p "$TEMP_DIR"/{bin,apps}
echo "#!/bin/bash" > "$TEMP_DIR/bin/test-tool"
echo "echo 'test from $WORKSPACE_INSTALL_DIR'" >> "$TEMP_DIR/bin/test-tool"
chmod +x "$TEMP_DIR/bin/test-tool"

cd "${RPM_BUILD_DIR}/temp"
tar -czf "${RPM_BUILD_DIR}/SOURCES/workspace-tools-1.0.0.tar.gz" workspace-tools-1.0.0
rm -rf "${RPM_BUILD_DIR}/temp"

if [ -f "${RPM_BUILD_DIR}/SOURCES/workspace-tools-1.0.0.tar.gz" ]; then
    echo -e "${GREEN}✓ 测试 tarball 创建成功${NC}"
    echo -e "  安装路径: ${WORKSPACE_INSTALL_DIR}"
else
    echo -e "${RED}✗ 测试 tarball 创建失败${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}所有测试通过！${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "系统已准备就绪，可以运行以下命令开始："
echo ""
echo -e "${YELLOW}# 使用默认路径${NC}"
echo -e "${GREEN}./compile.sh${NC}"
echo ""
echo -e "${YELLOW}# 指定工作区目录${NC}"
echo -e "${GREEN}WORKSPACE_DIR=/path/to/workspace ./compile.sh${NC}"
echo ""
echo -e "${YELLOW}# 指定安装路径${NC}"
echo -e "${GREEN}WORKSPACE_INSTALL_DIR=/custom/path ./compile.sh${NC}"
echo ""
echo -e "${YELLOW}# 或查看快速开始指南：${NC}"
echo -e "${GREEN}cat QUICKSTART.md${NC}"
