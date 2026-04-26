#!/bin/bash

# 工作区应用管理工具
# Workspace Application Management Tool

set -e

# 版本信息
VERSION="1.0.4"
PRODUCT_NAME="工作区应用管理工具"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 脚本所在目录（用于定位启动器）
SCRIPT_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# 当前工作目录（用于定位 apps 目录）
SCRIPT_DIR="$(pwd)"

# 检测实际用户（处理 sudo 情况）
# 优先级：SUDO_USER > pkexec 环境变量 > 登录用户
REAL_USER="${SUDO_USER:-${PKEXEC_UID:-}}"
if [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ]; then
    # 尝试获取图形会话的登录用户
    REAL_USER="$(loginctl show-session $(loginctl | grep $(who | head -1 | awk '{print $2}') 2>/dev/null | awk '{print $1}') -p Name 2>/dev/null | cut -d= -f2)"
    [ -z "$REAL_USER" ] && REAL_USER="$(who | head -1 | awk '{print $1}')"
fi
[ -z "$REAL_USER" ] && REAL_USER="$(whoami)"
REAL_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)"
[ -z "$REAL_HOME" ] && REAL_HOME="/home/$REAL_USER"

# 检测应用目录位置（优先使用当前工作目录）
if [ -d "$SCRIPT_DIR/apps" ]; then
    APPS_DIR="$SCRIPT_DIR/apps"
    LAUNCHER_SCRIPT="$SCRIPT_DIR/workspace-launcher"
elif [ -d "$SCRIPT_FILE_DIR/apps" ]; then
    # 回退到脚本所在目录
    APPS_DIR="$SCRIPT_FILE_DIR/apps"
    LAUNCHER_SCRIPT="$SCRIPT_FILE_DIR/workspace-launcher"
    SCRIPT_DIR="$SCRIPT_FILE_DIR"
else
    # 默认在当前工作目录创建
    APPS_DIR="$SCRIPT_DIR/apps"
    LAUNCHER_SCRIPT="$SCRIPT_DIR/workspace-launcher"
    mkdir -p "$APPS_DIR"
fi

# 确保 apps 目录存在
mkdir -p "$APPS_DIR"

# 应用信息变量
APP_NAME=""
APP_PATH=""
APP_ICON=""
WIN_DRIVES=""
APP_DESCRIPTION=""

# 显示帮助信息
show_help() {
    cat << EOF
${PRODUCT_NAME} v${VERSION}

用法:
    sudo $0 add         添加新应用 (需要管理员权限)
    sudo $0 remove <应用名>  删除应用 (需要管理员权限)
    $0 list              列出所有应用
    $0 help              显示此帮助信息

示例:
    $0 add
    $0 remove lu-measurement
    $0 list

EOF
}

# 显示错误信息
show_error() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit 1
}

# 显示成功信息
show_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 显示提示信息
show_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# 列出所有应用
list_apps() {
    echo -e "${BLUE}=== 已安装的应用 ===${NC}"
    echo ""
    
    local count=0
    for app_dir in "${APPS_DIR}"/*/; do
        if [ -d "$app_dir" ]; then
            local app_name=$(basename "$app_dir")
            local info_file="${app_dir}info"
            
            if [ -f "$info_file" ]; then
                local win_executable=""
                # 读取可执行文件路径
                win_executable=$(grep "^WIN_EXECUTABLE=" "$info_file" 2>/dev/null | cut -d'"' -f2)
                
                count=$((count + 1))
                echo -e "${GREEN}${count}. ${app_name}${NC}"
                echo -e "   路径: ${win_executable}"
                
                # 检查是否有桌面快捷方式
                if [ -f "/usr/share/applications/workspace-${app_name}.desktop" ]; then
                    echo -e "   ${YELLOW}✓ 已创建系统菜单${NC}"
                fi
                
                echo ""
            fi
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}未找到已安装的应用${NC}"
    fi
    
    echo -e "${BLUE}总计: ${count} 个应用${NC}"
}

# 删除应用
remove_app() {
    local app_name="$1"
    
    if [ -z "$app_name" ]; then
        show_error "请指定要删除的应用名称"
    fi
    
    local app_dir="${APPS_DIR}/${app_name}"
    
    # 检查应用是否存在
    if [ ! -d "$app_dir" ]; then
        show_error "应用 '${app_name}' 不存在"
    fi
    
    echo -e "${YELLOW}删除应用: ${app_name}${NC}"
    echo ""
    
    # 删除应用目录
    read -p "确认删除应用目录 '${app_dir}'? [Y/n]: " confirm
    if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
        rm -rf "$app_dir"
        show_success "已删除应用目录"
    fi
    
    # 删除桌面快捷方式
    local desktop_file="${HOME}/Desktop/workspace-${app_name}.desktop"
    if [ -f "$desktop_file" ]; then
        read -p "确认删除桌面快捷方式? [Y/n]: " confirm
        if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
            rm -f "$desktop_file"
            show_success "已删除桌面快捷方式"
        fi
    fi
    
    # 删除系统菜单项
    local menu_file="/usr/share/applications/workspace-${app_name}.desktop"
    if [ -f "$menu_file" ]; then
        read -p "确认删除系统菜单项? [Y/n]: " confirm
        if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
            rm -f "$menu_file"
            show_success "已删除系统菜单项"
        fi
    fi
    
    echo ""
    show_success "应用 '${app_name}' 已删除"
}

# 添加新应用
add_app() {
    echo -e "${BLUE}=== 添加新应用 ===${NC}"
    echo ""
    
    # 输入应用路径
    while [ -z "$APP_PATH" ]; do
        echo -n "请输入 Windows 应用完整路径 (例如: C:\\Program Files\\App.exe): "
        read -r APP_PATH
        
        # 验证路径格式
        if [[ ! "$APP_PATH" =~ ^[A-Za-z]:\\ ]]; then
            echo -e "${RED}错误: 路径格式不正确，应该是 Windows 路径格式 (例如: C:\\Program Files\\App.exe)${NC}"
            APP_PATH=""
        fi
    done
    
    # 从路径中提取应用名称（支持 Windows 路径）
    APP_NAME="${APP_PATH##*[/\\]}"  # 提取最后一个路径组件
    APP_NAME="${APP_NAME%.exe}"  # 移除 .exe 后缀
    APP_NAME="${APP_NAME%.EXE}"  # 移除 .EXE 后缀
    
    echo ""
    show_info "应用名称: ${APP_NAME}"
    echo ""
    
    # 询问是否使用自动生成的名称
    read -p "使用自动生成的应用名称 '${APP_NAME}'? (Y/n): " confirm
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        echo -n "请输入应用名称: "
        read -r APP_NAME
    fi
    
    # 检查应用是否已存在
    local app_dir="${APPS_DIR}/${APP_NAME}"
    if [ -d "$app_dir" ]; then
        show_error "应用 '${APP_NAME}' 已存在"
    fi
    
    # 输入应用描述
    echo ""
    echo -n "请输入应用描述 (可选，按回车跳过): "
    read -r APP_DESCRIPTION
    
    # 输入驱动映射
    echo ""
    show_info "配置驱动映射 (将 Linux 目录映射到 Windows)"
    echo "格式: 共享名:路径"
    echo "示例: LUData:/tmp/"
    echo ""
    read -p "是否需要配置驱动映射? [Y/n]: " confirm
    
    if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
        local drives=""
        local more_drives="y"
        
        while [ "$more_drives" = "y" ] || [ "$more_drives" = "Y" ]; do
            echo -n "请输入驱动映射 (共享名:路径): "
            read -r drive_config
            
            if [ -n "$drive_config" ]; then
                # 验证格式
                if [[ "$drive_config" =~ ^[^:]+:.+$ ]]; then
                    if [ -z "$drives" ]; then
                        drives="$drive_config"
                    else
                        drives="${drives},${drive_config}"
                    fi
                    
                    # 检查路径是否存在
                    local drive_path=$(echo "$drive_config" | cut -d':' -f2-)
                    if [ ! -d "$drive_path" ]; then
                        echo -e "${YELLOW}警告: 路径 '${drive_path}' 不存在${NC}"
                    fi
                else
                    echo -e "${RED}错误: 格式不正确，应为 '共享名:路径'${NC}"
                fi
            fi
            
            read -p "继续添加驱动映射? [Y/n]: " more_drives
        done
        
        WIN_DRIVES="$drives"
    fi
    
    # 输入图标路径
    echo ""
    read -p "是否需要指定应用图标? [Y/n]: " confirm
    if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
        echo -n "请输入图标文件路径 (PNG/SVG): "
        read -r APP_ICON
    fi
    
    # 确认信息
    echo ""
    echo -e "${BLUE}=== 应用信息确认 ===${NC}"
    echo "应用名称: ${APP_NAME}"
    echo "应用路径: ${APP_PATH}"
    if [ -n "$APP_DESCRIPTION" ]; then
        echo "应用描述: ${APP_DESCRIPTION}"
    fi
    if [ -n "$WIN_DRIVES" ]; then
        echo "驱动映射: ${WIN_DRIVES}"
    fi
    if [ -n "$APP_ICON" ]; then
        echo "图标路径: ${APP_ICON}"
    fi
    echo ""
    
    read -p "确认创建应用? (Y/n): " confirm
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        echo "操作已取消"
        exit 0
    fi
    
    # 创建应用目录
    mkdir -p "$app_dir"
    # 设置正确的权限（归属为实际用户）
    if [ "$(whoami)" = "root" ] && [ -n "$REAL_USER" ]; then
        chown -R "$REAL_USER:$REAL_USER" "$app_dir" 2>/dev/null || true
    fi
    show_success "已创建应用目录: ${app_dir}"
    
    # 生成配置文件
    cat > "${app_dir}/info" << EOF
# 应用配置文件
# 自动生成于 $(date '+%Y-%m-%d %H:%M:%S')

# Windows 应用路径
WIN_EXECUTABLE="${APP_PATH}"

EOF
    
    if [ -n "$WIN_DRIVES" ]; then
        cat >> "${app_dir}/info" << EOF
# 驱动映射配置
# 格式: WIN_DRIVES="共享名1:路径1,共享名2:路径2"
WIN_DRIVES="${WIN_DRIVES}"

EOF
    fi
    
    if [ -n "$APP_DESCRIPTION" ]; then
        cat >> "${app_dir}/info" << EOF
# 应用描述
APP_DESCRIPTION="${APP_DESCRIPTION}"

EOF
    fi
    
    show_success "已生成配置文件: ${app_dir}/info"
    
    # 复制图标文件（如果指定）
    if [ -n "$APP_ICON" ]; then
        if [ -f "$APP_ICON" ]; then
            cp "$APP_ICON" "${app_dir}/icon.svg"
            show_success "已复制图标文件"
        else
            echo -e "${YELLOW}警告: 图标文件 '${APP_ICON}' 不存在，将使用默认图标${NC}"
        fi
    fi
    
    # 询问是否创建桌面快捷方式
    echo ""
    read -p "是否创建桌面快捷方式? (Y/n): " confirm
    if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
        create_desktop_shortcut
    fi
    
    # 询问是否创建系统菜单项
    read -p "是否创建系统菜单项? (Y/n): " confirm
    if [ "$confirm" != "n" ] && [ "$confirm" != "N" ]; then
        create_menu_entry
    fi
    
    echo ""
    show_success "应用 '${APP_NAME}' 添加成功！"
    echo ""
    echo "应用目录: ${app_dir}"
    echo "配置文件: ${app_dir}/info"
    echo "启动命令: ${LAUNCHER_SCRIPT} ${APP_NAME}"
    echo ""
    show_info "您现在可以使用以下命令启动应用:"
    echo "  ${LAUNCHER_SCRIPT} ${APP_NAME}"
}

# 创建桌面快捷方式
create_desktop_shortcut() {
    # 使用实际用户（处理 sudo 情况）
    local desktop_user="$REAL_USER"
    local desktop_home="$REAL_HOME"
    
    # 如果获取失败，使用当前的 HOME
    if [ -z "$desktop_home" ]; then
        desktop_home="$HOME"
    fi
    
    show_info "桌面用户: ${desktop_user}"
    show_info "桌面用户目录: ${desktop_home}"
    show_info "启动器路径: ${LAUNCHER_SCRIPT}"
    
    local desktop_dir="${desktop_home}/Desktop"
    
    # 如果 Desktop 目录不存在，使用中文桌面目录
    if [ ! -d "$desktop_dir" ]; then
        desktop_dir="${desktop_home}/桌面"
    fi
    
    # 检查并创建默认应用图标
    local default_icon="/usr/share/pixmaps/default-app-icon.svg"
    if [ ! -f "$default_icon" ]; then
        mkdir -p "/usr/share/pixmaps"
        cat > "$default_icon" << 'DEFAULT_ICON_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <defs>
    <linearGradient id="appGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4a90e2;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0056b3;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#appGradient)"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="white" font-size="24" font-family="Arial, sans-serif" font-weight="bold">
    A
  </text>
</svg>
DEFAULT_ICON_EOF
        echo "已创建默认应用图标: $default_icon"
    fi
    
    local desktop_file="${desktop_dir}/workspace-${APP_NAME}.desktop"
    
    # 确定图标路径
    local icon_path="${app_dir}/icon.svg"
    local default_icon="/usr/share/pixmaps/default-app-icon.svg"
    
    # 如果应用图标不存在，使用系统默认图标
    if [ ! -f "$icon_path" ]; then
        icon_path="$default_icon"
    fi
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Comment=${APP_DESCRIPTION:-Workspace Application}
Exec=${LAUNCHER_SCRIPT} ${APP_NAME}
Icon=${icon_path}
Terminal=false
Path=${SCRIPT_DIR}
Categories=Application;
EOF
    
    chmod 644 "$desktop_file"
    # 修正文件归属为实际用户
    chown "$REAL_USER:$REAL_USER" "$desktop_file" 2>/dev/null || true
    show_success "已创建桌面快捷方式: ${desktop_file}"
}

# 创建系统菜单项
create_menu_entry() {
    local menu_dir="/usr/share/applications"
    
    # 检查是否需要管理员权限
    if [ ! -w "$menu_dir" ]; then
        show_info "需要管理员权限来创建系统菜单项，跳过"
        return 0
    fi
    
    mkdir -p "$menu_dir"
    
    # 检查并创建默认应用图标
    local default_icon="/usr/share/pixmaps/default-app-icon.svg"
    if [ ! -f "$default_icon" ]; then
        mkdir -p "/usr/share/pixmaps"
        cat > "$default_icon" << 'DEFAULT_ICON_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <defs>
    <linearGradient id="appGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4a90e2;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0056b3;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#appGradient)"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="white" font-size="24" font-family="Arial, sans-serif" font-weight="bold">
    A
  </text>
</svg>
DEFAULT_ICON_EOF
        echo "已创建默认应用图标: $default_icon"
    fi
    
    local menu_file="${menu_dir}/workspace-${APP_NAME}.desktop"
    
    # 确定图标路径
    local icon_path="${app_dir}/icon.svg"
    
    # 如果应用图标不存在，使用系统默认图标
    if [ ! -f "$icon_path" ]; then
        icon_path="$default_icon"
    fi
    
    cat > "$menu_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Comment=${APP_DESCRIPTION:-Workspace Application}
Exec=${LAUNCHER_SCRIPT} ${APP_NAME}
Icon=${icon_path}
Terminal=false
Categories=Application;
EOF
    
    # 设置正确的权限
    chmod 644 "$menu_file"
    show_success "已创建系统菜单项: ${menu_file}"
}

# 主函数
main() {
    case "$1" in
        add)
            add_app
            ;;
        remove)
            remove_app "$2"
            ;;
        list)
            list_apps
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            if [ -z "$1" ]; then
                show_help
            else
                show_error "未知命令: $1"
                show_help
                exit 1
            fi
            ;;
    esac
}

# 运行主函数
main "$@"
