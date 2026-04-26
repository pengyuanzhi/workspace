#!/bin/bash

# 工作区编译脚本 - 将 .sh 和 .py 文件编译成二进制文件

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
DATE=$(date +%Y%m%d_%H%M%S)

# 支持通过环境变量自定义安装目录
INSTALL_DIR="${WORKSPACE_INSTALL_DIR:-/opt/workspace}"
APP_NAME="workspace-tools"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}工作区编译脚本${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "源目录: ${SOURCE_DIR}"
echo "构建目录: ${BUILD_DIR}"
echo "时间: ${DATE}"
echo ""

# 检查源目录
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}错误: 源目录不存在: ${SOURCE_DIR}${NC}"
    exit 1
fi

# 步骤 1: 创建构建目录
echo -e "${BLUE}[1/5] 创建构建目录...${NC}"
mkdir -p "$BUILD_DIR"
echo -e "${GREEN}✓ 构建目录已创建${NC}"
echo ""

# 步骤 2: 检查编译工具
echo -e "${BLUE}[2/5] 检查编译工具...${NC}"

# 检查 Python
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python: ${PYTHON_VERSION}${NC}"
else
    echo -e "${RED}✗ Python 未安装${NC}"
    exit 1
fi

# 检查 PyInstaller
PYINSTALLER_AVAILABLE=false
if python3 -c "import PyInstaller" 2>/dev/null; then
    PYINSTALLER_AVAILABLE=true
    PYINSTALLER_VERSION=$(python3 -c "import PyInstaller; print(PyInstaller.__version__)")
    echo -e "${GREEN}✓ PyInstaller: ${PYINSTALLER_VERSION}${NC}"
else
    echo -e "${YELLOW}⚠ PyInstaller 未安装${NC}"
fi

# 检查 shc
SHC_AVAILABLE=false
if command -v shc >/dev/null 2>&1; then
    SHC_AVAILABLE=true
    echo -e "${GREEN}✓ shc 已安装${NC}"
else
    echo -e "${YELLOW}⚠ shc 未安装${NC}"
fi

echo ""

# 步骤 3: 编译 Python 脚本
echo -e "${BLUE}[3/5] 编译 Python 脚本...${NC}"
PYTHON_SCRIPTS=($(find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.py" | sort))

if [ ${#PYTHON_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}未找到 Python 脚本${NC}"
else
    echo "找到 ${#PYTHON_SCRIPTS[@]} 个 Python 脚本:"
    for script in "${PYTHON_SCRIPTS[@]}"; do
        echo "  - $(basename "$script")"
    done
    echo ""

    for script in "${PYTHON_SCRIPTS[@]}"; do
        script_name=$(basename "$script")
        script_basename="${script_name%.py}"
        
        echo "编译: $script_name"
        
        if [ "$PYINSTALLER_AVAILABLE" = true ]; then
            echo "  使用 PyInstaller 编译..."
            
            # 清理
            cd "$SOURCE_DIR"
            rm -rf ".pyinstaller_build/${script_basename}" 2>/dev/null || true
            rm -f "${script_basename}" 2>/dev/null || true
            rm -f "${script_basename}.spec" 2>/dev/null || true
            
            # 编译
            if python3 -m PyInstaller --onefile --name="$script_basename" --distpath="$BUILD_DIR" --workpath="$BUILD_DIR/.pyinstaller" --noconfirm --clean "$script" 2>/dev/null; then
                echo -e "  ${GREEN}✓ PyInstaller 编译成功${NC}"
            else
                echo -e "  ${RED}✗ PyInstaller 编译失败${NC}"
                # 使用字节码
                python3 -m py_compile "$script"
                pyc_file=$(find "__pycache__" -name "${script_basename}*.cpython*.pyc" 2>/dev/null | head -1)
                if [ -n "$pyc_file" ] && [ -f "$pyc_file" ]; then
                    cp "$pyc_file" "${BUILD_DIR}/${script_basename}.pyc"
                    echo -e "  ${YELLOW}⚠ 已生成字节码${NC}"
                fi
            fi
            
            # 清理
            rm -rf ".pyinstaller_build/${script_basename}" 2>/dev/null || true
            rm -f "${script_basename}" 2>/dev/null || true
            rm -f "${script_basename}.spec" 2>/dev/null || true
        else
            echo "  使用字节码编译..."
            python3 -m py_compile "$script"
            pyc_file=$(find "__pycache__" -name "${script_basename}*.cpython*.pyc" 2>/dev/null | head -1)
            if [ -n "$pyc_file" ] && [ -f "$pyc_file" ]; then
                cp "$pyc_file" "${BUILD_DIR}/${script_name}.pyc"
                echo -e "  ${GREEN}✓ 字节码编译成功${NC}"
            fi
        fi
        
        echo ""
    done
fi

# 步骤 4: 编译 Bash 脚本
echo -e "${BLUE}[4/5] 编译 Bash 脚本...${NC}"
BASH_SCRIPTS=($(find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.sh" | sort))

# 过滤
FILTERED_SCRIPTS=()
for script in "${BASH_SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    if [ "$script_name" != "compile.sh" ] && [ "$script_name" != "package-rpm.sh" ] && [ "$script_name" != "test-rpm-build.sh" ] && [ "$script_name" != "verify-fix.sh" ] && [ -s "$script" ]; then
        FILTERED_SCRIPTS+=("$script")
    fi
done

if [ ${#FILTERED_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}未找到 Bash 脚本${NC}"
else
    echo "找到 ${#FILTERED_SCRIPTS[@]} 个 Bash 脚本:"
    for script in "${FILTERED_SCRIPTS[@]}"; do
        echo "  - $(basename "$script")"
    done
    echo ""

    for script in "${FILTERED_SCRIPTS[@]}"; do
        script_name=$(basename "$script")
        script_basename="${script_name%.sh}"
        
        echo "编译: $script_name"
        
        if [ "$SHC_AVAILABLE" = true ]; then
            echo "  使用 shc 编译..."
            cd "$SOURCE_DIR"
            
            # 清理
            rm -f "${script_basename}" 2>/dev/null || true
            rm -f "${script_name}.x" 2>/dev/null || true
            rm -f "${script_name}.x.c" 2>/dev/null || true
            
            # 编译
            if shc -r -f "$script" 2>/dev/null; then
                if [ -f "${script_name}.x" ]; then
                    cp "${script_name}.x" "${BUILD_DIR}/${script_basename}"
                    chmod +x "${BUILD_DIR}/${script_basename}"
                    rm -f "${script_name}.x.c" 2>/dev/null || true
                    rm -f "${script_name}.x" 2>/dev/null || true
                    echo -e "  ${GREEN}✓ shc 编译成功${NC}"
                else
                    echo -e "  ${RED}✗ shc 编译失败${NC}"
                    cp "$script" "${BUILD_DIR}/"
                    chmod 500 "${BUILD_DIR}/${script_name}"
                fi
            else
                echo -e "  ${YELLOW}⚠ shc 编译失败，使用源码${NC}"
                cp "$script" "${BUILD_DIR}/"
                chmod 500 "${BUILD_DIR}/${script_name}"
            fi
        else
            echo -e "  ${YELLOW}⚠ shc 未安装，使用源码${NC}"
            cp "$script" "${BUILD_DIR}/"
            chmod 500 "${BUILD_DIR}/${script_name}"
        fi
        
        echo ""
    done
fi

# 步骤 5: 复制其他文件
echo -e "${BLUE}[5/5] 复制其他必要文件...${NC}"

if [ -f "${SOURCE_DIR}/workspace.conf" ]; then
    cp "${SOURCE_DIR}/workspace.conf" "${BUILD_DIR}/"
    echo -e "${GREEN}✓ 已复制: workspace.conf${NC}"
fi

if [ -d "${SOURCE_DIR}/apps" ]; then
    cp -r "${SOURCE_DIR}/apps" "${BUILD_DIR}/"
    echo -e "${GREEN}✓ 已复制: apps/ 目录${NC}"
fi

if [ -d "${SOURCE_DIR}/bin" ]; then
    cp -r "${SOURCE_DIR}/bin" "${BUILD_DIR}/"
    echo -e "${GREEN}✓ 已复制: bin/ 目录${NC}"
fi

echo ""

# 创建安装脚本
cat > "${BUILD_DIR}/install.sh" << 'EOF'
#!/bin/bash
if [ "$(whoami)" != "root" ]; then
    echo "需要 root 权限"
    exit 1
fi
TARGET="/home/sclead/workspace"
# 不再备份，直接覆盖
cp -r "$(dirname "$0")"/* "$TARGET/"
chmod +x "$TARGET"/*
echo "安装完成"
EOF
chmod +x "${BUILD_DIR}/install.sh"
echo -e "${GREEN}✓ 已创建安装脚本${NC}"

# 创建 README
cat > "${BUILD_DIR}/README.md" << 'EOF'
# 工作区编译版本

编译日期: 2026-04-25

安装方法:
  sudo ./install.sh

安全性: 源代码不可读
EOF

# 清理
rm -rf "$SOURCE_DIR/__pycache__" 2>/dev/null || true

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}编译完成${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "构建目录: ${BUILD_DIR}"
echo ""

# 统计
echo -e "${YELLOW}编译统计:${NC}"
echo ""

if [ ${#PYTHON_SCRIPTS[@]} -gt 0 ]; then
    echo -e "${GREEN}Python 脚本: ${#PYTHON_SCRIPTS[@]} 个${NC}"
    if [ "$PYINSTALLER_AVAILABLE" = true ]; then
        echo "  方法: PyInstaller"
    else
        echo "  方法: 字节码"
    fi
fi

if [ ${#FILTERED_SCRIPTS[@]} -gt 0 ]; then
    echo -e "${GREEN}Bash 脚本: ${#FILTERED_SCRIPTS[@]} 个${NC}"
    if [ "$SHC_AVAILABLE" = true ]; then
        echo "  方法: shc (二进制)"
    else
        echo "  方法: 源码"
    fi
fi

echo ""
echo -e "${YELLOW}文件大小:${NC}"
echo ""

find "$BUILD_DIR" -name "workspace-*" -type f | while read file; do
    if [ -x "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        name=$(basename "$file")
        echo "  $name: $size"
    fi
done

echo ""
echo -e "${BLUE}下一步:${NC}"
echo ""
echo "1. 测试: cd ${BUILD_DIR} && ./workspace-launcher help"
echo "2. 安装: cd ${BUILD_DIR} && sudo ./install.sh"
echo "3. 打包: ./package-rpm.sh (创建可通过 dnf 安装的 RPM 包)"
echo ""

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}编译完成！${NC}"
echo -e "${BLUE}=========================================${NC}"

# 询问是否立即打包成 RPM
if [ -f "${SOURCE_DIR}/package-rpm.sh" ]; then
    read -p "是否立即打包成 RPM 包? (y/N): " pack_now
    if [[ "$pack_now" =~ ^[Yy]$ ]]; then
        echo ""
        chmod +x "${SOURCE_DIR}/package-rpm.sh"
        "${SOURCE_DIR}/package-rpm.sh"
    fi
fi
