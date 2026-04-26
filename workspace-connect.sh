#!/bin/bash

# 工作区连接工具 - 产品版
# Workspace Connection Tool

set -e

# 版本信息
VERSION="1.5.0"
PRODUCT_NAME="工作区连接工具"

# 默认配置参数（硬编码）
DEFAULT_SCALE=100
DEFAULT_FLAGS="+clipboard"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 打印标题
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       $PRODUCT_NAME${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# 打印提示
print_prompt() {
    echo -e "${GREEN}➜ $1${NC}"
}

# 打印警告
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 打印错误
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# 打印分隔线
print_separator() {
    echo -e "${BLUE}----------------------------------------${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
$PRODUCT_NAME v$VERSION

使用方法: workspace-connect <命令> [选项]

可用命令:
  remote, connect      连接到远程工作区
  status, info        查看当前状态
  config              管理配置
  help                显示此帮助信息

连接选项:
  -c, --config FILE   指定配置文件路径
  -h, --help          显示帮助信息

环境变量:
  WORKSPACE_CONFIG    配置文件路径

配置说明:
  默认位置: ./workspace.conf (程序所在目录)
  备选位置: ~/.config/appsphere/appsphere.conf (向后兼容)
  自动查找: 支持多用户配置文件自动发现

使用示例:
  # 连接到远程工作区
  workspace-connect remote
  
  # 查看当前状态
  workspace-connect status
  
  # 使用指定配置连接
  workspace-connect remote -c /path/to/config.conf

  # 使用简化命令
  workspace-connect
  ws-connect

EOF
}

# 显示状态信息
show_status() {
    clear
    print_header
    
    # 读取配置文件
    read_config
    
    echo -e "${GREEN}系统状态${NC}"
    echo ""
    
    # 检查连接工具
    if [ -x "/usr/local/bin/xfreerdp" ]; then
        echo -e "  ${GREEN}✓${NC} 远程连接工具: 已就绪"
    else
        echo -e "  ${RED}✗${NC} 远程连接工具: 未安装"
    fi
    
    # 检查配置信息
    if [ -n "$CONFIG_HOST" ]; then
        echo -e "  ${GREEN}✓${NC} 工作区地址: $CONFIG_HOST"
    fi
    if [ -n "$CONFIG_USERNAME" ]; then
        echo -e "  ${GREEN}✓${NC} 用户: $CONFIG_USERNAME"
    fi
    
    echo ""
    print_separator
    echo ""
}

# 读取配置文件
read_config() {
    local config_file
    local conf_path
    local user_home
    local script_dir
    local key value
    
    # 优先级：1. 命令行参数 > 2. 环境变量 > 3. 当前目录 > 4. 程序目录 > 5. 用户目录 > 6. 系统扫描
    
    # 1. 使用全局变量（来自命令行参数）
    if [ -n "$CONFIG_FILE_PATH" ]; then
        config_file="$CONFIG_FILE_PATH"
    # 2. 使用环境变量
    elif [ -n "$WORKSPACE_CONFIG" ]; then
        config_file="$WORKSPACE_CONFIG"
    # 3. 查找当前目录下的 workspace.conf
    elif [ -f "./workspace.conf" ]; then
        config_file="./workspace.conf"
    # 4. 查找程序所在目录下的 workspace.conf
    elif [ -n "$0" ] && [ "$0" != "bash" ] && [ "$0" != "sh" ]; then
        script_dir=$(dirname "$0")
        conf_path="${script_dir}/workspace.conf"
        if [ -f "$conf_path" ]; then
            config_file="$conf_path"
        fi
    # 4.5. 尝试使用 realpath 获取真实路径
    elif [ -n "$0" ] && command -v realpath &> /dev/null; then
        script_path=$(realpath "$0")
        if [ -f "$script_path" ]; then
            script_dir=$(dirname "$script_path")
            conf_path="${script_dir}/workspace.conf"
            if [ -f "$conf_path" ]; then
                config_file="$conf_path"
            fi
        fi
    # 5. 查找用户主目录下的配置文件（向后兼容）
    elif [ -f "$HOME/.config/appsphere/appsphere.conf" ]; then
        config_file="$HOME/.config/appsphere/appsphere.conf"
    # 6. 尝试检测实际的用户主目录（如果是root用户）
    elif [ "$(id -un)" = "root" ]; then
        # 查找 /home 下第一个有配置文件的用户
        for user_home in /home/*/; do
            conf_path="${user_home}.config/appsphere/appsphere.conf"
            if [ -f "$conf_path" ]; then
                config_file="$conf_path"
                break
            fi
        done
    fi
    
    # 保存配置文件路径供后续使用
    CONFIG_FILE="$config_file"
    
    # 如果找到配置文件，则读取
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        # 读取配置项
        while IFS='=' read -r key value; do
            # 跳过注释和空行
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [ -z "$key" ] && continue

            # 去除空格
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            # 去除引号（使用sed）
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

            # 映射到配置变量
            case "$key" in
                host|ip|server|address|RDP_IP|WS_IP)
                    CONFIG_HOST="$value"
                    ;;
                username|user|RDP_USER|WS_USER)
                    CONFIG_USERNAME="$value"
                    ;;
                password|pass|RDP_PASS|WS_PASS)
                    CONFIG_PASSWORD="$value"
                    ;;
            esac
        done < "$config_file"
    fi
}

# 更新配置文件
update_config() {
    local host="$1"
    local username="$2"
    local password="$3"
    
    # 如果没有配置文件，创建在当前目录下
    if [ -z "$CONFIG_FILE" ]; then
        CONFIG_FILE="./workspace.conf"
    fi
    
    # 确保目录存在
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 如果配置文件不存在，创建新文件
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
# Workspace Connect 配置文件
# 将此文件与 workspace-connect 放在同一个目录下使用

# 工作区信息
WS_IP="$host"
WS_USER="$username"
WS_PASS="$password"
EOF
        echo -e "${YELLOW}已创建新配置文件: $CONFIG_FILE${NC}"
        return
    fi
    
    # 更新现有配置文件
    local temp_file=$(mktemp)
    local updated=false
    
    # 处理文件，更新相应的配置项
    while IFS= read -r line || [ -n "$line" ]; do
        local skip_line=false
        
        # 检查是否是 WS_IP 行
        if [[ "$line" =~ ^WS_IP= ]]; then
            echo "WS_IP=\"$host\""
            skip_line=true
            updated=true
        # 检查是否是 WS_USER 行
        elif [[ "$line" =~ ^WS_USER= ]]; then
            echo "WS_USER=\"$username\""
            skip_line=true
            updated=true
        # 检查是否是 WS_PASS 行
        elif [[ "$line" =~ ^WS_PASS= ]]; then
            echo "WS_PASS=\"$password\""
            skip_line=true
            updated=true
        fi
        
        if [ "$skip_line" = false ]; then
            echo "$line"
        fi
    done < "$CONFIG_FILE" > "$temp_file"
    
    # 如果配置文件中没有这些项，则添加
    if [ "$updated" = false ]; then
        cat >> "$temp_file" << EOF

# Workspace Connect 配置文件
WS_IP="$host"
WS_USER="$username"
WS_PASS="$password"
EOF
    fi
    
    # 替换原文件
    mv "$temp_file" "$CONFIG_FILE"
    echo -e "${YELLOW}已更新配置文件: $CONFIG_FILE${NC}"
}

# 检查连接工具
check_tool() {
    if [ ! -x "/usr/local/bin/xfreerdp" ]; then
        print_error "未找到连接工具"
        echo "请确保已正确安装工作区连接工具"
        exit 1
    fi
}

# 获取用户输入
get_input() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"

    if [ -n "$default" ]; then
        read -p "$(print_prompt "$prompt [$default]: ")" "$var_name"
        eval "$var_name=\${$var_name:-$default}"
    else
        read -p "$(print_prompt "$prompt: ")" "$var_name"
    fi
}

# 获取密码输入（隐藏显示）
get_password() {
    local prompt="$1"
    local var_name="$2"

    read -s -p "$(print_prompt "$prompt: ")" "$var_name"
    echo ""
}

# 打印分隔线
print_config_info() {
    print_separator
}

# 连接到远程工作区
connect_remote() {
    clear
    print_header
    
    # 检查连接工具
    check_tool
    
    # 读取配置文件
    read_config
    
    # 打印配置文件信息
    print_config_info
    
    # 获取连接信息
    print_separator
    
    local host
    local username
    local password
    local new_input=false
    
    # 输入工作区地址
    if [ -n "$CONFIG_HOST" ]; then
        echo -e "${YELLOW}已保存的工作区地址: $CONFIG_HOST${NC}"
        read -p "$(print_prompt "是否使用此地址? [Y/n]: ")" use_config
        if [[ "$use_config" =~ ^[Nn]$ ]]; then
            get_input "请输入工作区地址" host
            new_input=true
        else
            host="$CONFIG_HOST"
        fi
    else
        get_input "请输入工作区地址" host
        new_input=true
    fi
    
    # 输入用户名
    if [ -n "$CONFIG_USERNAME" ]; then
        echo -e "${YELLOW}已保存的用户名: $CONFIG_USERNAME${NC}"
        read -p "$(print_prompt "是否使用此用户名? [Y/n]: ")" use_config
        if [[ "$use_config" =~ ^[Nn]$ ]]; then
            get_input "请输入用户名" username
            new_input=true
        else
            username="$CONFIG_USERNAME"
        fi
    else
        get_input "请输入用户名" username
        new_input=true
    fi
    
    # 输入密码
    if [ -n "$CONFIG_PASSWORD" ]; then
        echo -e "${YELLOW}已保存的认证信息已设置${NC}"
        read -p "$(print_prompt "是否使用已保存的认证? [Y/n]: ")" use_config
        if [[ "$use_config" =~ ^[Nn]$ ]]; then
            get_password "请输入认证密码" password
            new_input=true
        else
            password="$CONFIG_PASSWORD"
        fi
    else
        get_password "请输入认证密码" password
        new_input=true
    fi
    
    # 验证输入
    if [ -z "$host" ] || [ -z "$username" ] || [ -z "$password" ]; then
        print_error "工作区地址、用户名和认证密码不能为空"
        exit 1
    fi
    
    # 只有在有新输入时，才询问是否保存
    if [ "$new_input" = true ]; then
        # 显示将要使用的配置
        echo -e "${YELLOW}将要使用的连接信息:${NC}"
        echo -e "  工作区地址: $host"
        echo -e "  用户名: $username"
        echo -e "  认证: ***${NC}"
        echo ""
        
        # 询问是否保存配置到文件
        read -p "$(print_prompt "是否保存此配置到文件? [Y/n]: ")" save_config
        if [[ "$save_config" =~ ^[Yy] ]] || [ -z "$save_config" ]; then
            update_config "$host" "$username" "$password"
        fi
    fi
    
    print_separator
    
    # 构建连接命令
    local cmd="/usr/local/bin/xfreerdp"
    cmd="$cmd /v:$host:3389"
    cmd="$cmd /u:$username"
    cmd="$cmd /p:$password"
    cmd="$cmd $DEFAULT_FLAGS"
    cmd="$cmd /scale:$DEFAULT_SCALE"
    cmd="$cmd /title:工作区"
    
    # 显示连接信息
    echo -e "${GREEN}正在连接到工作区...${NC}"
    echo -e "${GREEN}地址: ${BLUE}$host${NC}"
    echo -e "${GREEN}用户: ${BLUE}$username${NC}"
    print_separator
    echo ""
    
    # 执行连接（隐藏所有输出）
    eval $cmd >/dev/null 2>&1
    
    # 连接结束
    print_separator
    echo -e "${GREEN}工作区连接已关闭${NC}"
    echo ""
}

# 解析命令行参数
CONFIG_FILE_PATH=""
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        remote|connect)
            COMMAND="connect"
            shift
            ;;
        status|info)
            COMMAND="status"
            shift
            ;;
        config)
            COMMAND="config"
            shift
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE_PATH="$2"
            shift 2
            ;;
        *)
            # 如果没有指定命令，默认为连接
            if [ -z "$COMMAND" ]; then
                COMMAND="connect"
                # 第一个参数可能是工作区地址
                if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    CONFIG_HOST="$1"
                fi
            fi
            shift
            ;;
    esac
done

# 默认命令是连接
if [ -z "$COMMAND" ]; then
    COMMAND="connect"
fi

# 执行命令
case "$COMMAND" in
    connect)
        connect_remote
        ;;
    status)
        show_status
        ;;
    config)
        show_help
        echo ""
        echo -e "${YELLOW}配置文件路径: ${BLUE}$HOME/.config/appsphere/appsphere.conf${NC}"
        echo -e "${YELLOW}或者使用: ${BLUE}workspace-connect remote -c <配置文件路径>${NC}"
        echo ""
        ;;
    *)
        show_help
        exit 1
        ;;
esac
