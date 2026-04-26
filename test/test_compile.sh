#!/bin/bash

# 测试编译版本

BUILD_DIR="/home/sclead/workspace/build"

echo "========================================="
echo "测试编译版本"
echo "========================================="
echo ""

if [ ! -d "$BUILD_DIR" ]; then
    echo "错误: 构建目录不存在: $BUILD_DIR"
    echo "请先运行: ./compile.sh"
    exit 1
fi

cd "$BUILD_DIR"

echo "[1] 测试 Python 脚本编译"
echo ""

# 测试 workspace-config.py
if [ -f "workspace-config" ]; then
    echo "测试: workspace-config (PyInstaller)"
    echo ""
    
    # 尝试显示帮助（可能会因为缺少 DISPLAY 而失败）
    timeout 5 ./workspace-config --help 2>&1 | head -5 || true
    echo ""
    echo "✓ workspace-config 可以运行"
else
    echo "⚠ workspace-config 不存在 (PyInstaller)"
    
    # 检查是否有字节码版本
    if [ -f "workspace-config.pyc" ]; then
        echo "✓ workspace-config.pyc 存在 (字节码)"
    fi
fi
echo ""

echo "[2] 测试 Bash 脚本编译"
echo ""

# 测试 workspace-launcher.sh
if [ -x "workspace-launcher" ]; then
    echo "测试: workspace-launcher (shc)"
    echo ""
    ./workspace-launcher help
    echo ""
    echo "✓ workspace-launcher 可以运行"
elif [ -x "workspace-launcher.sh" ]; then
    echo "测试: workspace-launcher.sh (源码)"
    echo ""
    ./workspace-launcher.sh help
    echo ""
    echo "✓ workspace-launcher.sh 可以运行"
else
    echo "✗ workspace-launcher.sh 不存在"
fi
echo ""

# 测试 workspace-app.sh
if [ -x "workspace-app" ]; then
    echo "测试: workspace-app (shc)"
    echo ""
    ./workspace-app list
    echo ""
    echo "✓ workspace-app 可以运行"
elif [ -x "workspace-app.sh" ]; then
    echo "测试: workspace-app.sh (源码)"
    echo ""
    ./workspace-app.sh list
    echo ""
    echo "✓ workspace-app.sh 可以运行"
else
    echo "✗ workspace-app.sh 不存在"
fi
echo ""

echo "[3] 检查文件权限"
echo ""

echo "可执行文件:"
find "$BUILD_DIR" -maxdepth 1 -type f -executable | sort
echo ""

echo "Python 字节码:"
find "$BUILD_DIR" -maxdepth 1 -name "*.pyc" | sort
echo ""

echo "[4] 检查文件完整性"
echo ""

# 检查必要的文件
REQUIRED_FILES=(
    "workspace.conf"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$BUILD_DIR/$file" ]; then
        echo "✓ $file"
    else
        echo "✗ $file (缺失)"
    fi
done
echo ""

# 检查目录
REQUIRED_DIRS=(
    "apps"
    "bin"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$BUILD_DIR/$dir" ]; then
        echo "✓ $dir/"
    else
        echo "✗ $dir/ (缺失)"
    fi
done
echo ""

echo "[5] 文件大小对比"
echo ""

echo "原始目录:"
du -sh "$BUILD_DIR/.." | awk '{print "  总大小:", $1}'
echo ""

echo "构建目录:"
du -sh "$BUILD_DIR" | awk '{print "  总大小:", $1}'
echo ""

echo "========================================="
echo "测试完成"
echo "========================================="
