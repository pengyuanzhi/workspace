#!/bin/bash

### GLOBAL CONSTANTS ###

# ERROR CODES
readonly EC_MISSING_CONFIG=1
readonly EC_MISSING_CLIENT=2
readonly EC_NOT_IN_GROUP=3
readonly EC_FAIL_START=4
readonly EC_FAIL_RESUME=5
readonly EC_FAIL_DESTROY=6
readonly EC_SD_TIMEOUT=7
readonly EC_DIE_TIMEOUT=8
readonly EC_RESTART_TIMEOUT=9
readonly EC_NOT_EXIST=10
readonly EC_UNKNOWN=11
readonly EC_NO_IP=12
readonly EC_BAD_PORT=13
readonly EC_UNSUPPORTED_APP=14
readonly EC_INVALID_FLAVOR=15
readonly EC_NO_DISPLAY=16

# PATHS
# shellcheck disable=SC2155
readonly SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# 应用数据目录
readonly APPDATA_PATH="${SCRIPT_DIR_PATH}/apps"
# 配置文件路径
readonly CONFIG_PATH="${SCRIPT_DIR_PATH}/workspace.conf"
# 最后运行时间
readonly LASTRUN_PATH="${APPDATA_PATH}/lastrun"
# 日志文件
readonly LOG_PATH="${APPDATA_PATH}/workspace-launcher.log"
# 活动检测与休眠标记
readonly SLEEP_DETECT_PATH="${APPDATA_PATH}/last_activity"
readonly SLEEP_MARKER="${APPDATA_PATH}/sleep_marker"

# OTHER
readonly CONTAINER_NAME="WorkspaceContainer"
# 默认端口，可被配置文件覆盖
WS_PORT=3389
readonly DOCKER_IP="127.0.0.1"
# shellcheck disable=SC2155
readonly RUNID="${RANDOM}"

### GLOBAL VARIABLES ###

# 配置变量
WS_USER=""
WS_PASS=""
WS_ASKPASS=""
WS_DOMAIN=""
WS_IP=""
VM_NAME="WorkspaceVM"
WAFLAVOR="libvirt" # 默认为 libvirt

# 客户端配置
CLIENT_COMMAND=""
CLIENT_FLAGS=""
DEBUG="false"
BOOT_TIMEOUT=120
HIDEF="on"
AUTOPAUSE="off"
AUTOPAUSE_TIME="300"

# 进程管理
CLIENT_PID=-1
NEEDED_BOOT=false

### TRAPS ###
trap killClientCleanExit SIGINT SIGTERM

### FUNCTIONS ###

# 函数名：cleanProcesses
# 角色：清理残留的进程标记文件 (不再包含 Client/FreeRDP)
function cleanProcesses() {
    for proc_file in "${APPDATA_PATH}"/Process_*.cproc; do
        [[ -f "$proc_file" ]] || break
        cproc=$(basename "$proc_file")
        cproc="${cproc#Process_}"
        cproc="${cproc%.cproc}"
        if [[ "$cproc" =~ ^[0-9]+$ ]]; then
            if [[ ! -d "/proc/$cproc" ]] || [[ ! -r "/proc/$cproc/comm" ]] || [[ $(<"/proc/$cproc/comm") != *xfreerdp* ]]; then
                rm -- "$proc_file" &>/dev/null
                dprint "清理残留: $proc_file"
            fi
        fi
    done
}

# 函数名：killClient
# 角色：终止客户端进程
function killClient() {
    local TERMINATED_PROCESS_IDS=()
    for CLIENT_PROCESS_FILE in "${APPDATA_PATH}/Process_"*.cproc; do
        [[ -f "$CLIENT_PROCESS_FILE" ]] || break
        CLIENT_PROCESS_FILE=$(basename "$CLIENT_PROCESS_FILE")
        CLIENT_PROCESS_FILE="${CLIENT_PROCESS_FILE#Process_}"
        CLIENT_PROCESS_FILE="${CLIENT_PROCESS_FILE%.cproc}"
        
        if [[ "$CLIENT_PROCESS_FILE" =~ ^[0-9]+$ ]] && [[ -d "/proc/$CLIENT_PROCESS_FILE" ]]; then
            kill -15 "$CLIENT_PROCESS_FILE" &>/dev/null
            # 等待终止
            for _ in {1..5}; do
                sleep 1
                [[ ! -d "/proc/$CLIENT_PROCESS_FILE" ]] && break
            done
            # 强制终止
            if [[ -d "/proc/$CLIENT_PROCESS_FILE" ]]; then
                kill -9 "$CLIENT_PROCESS_FILE" &>/dev/null
            fi
            TERMINATED_PROCESS_IDS+=("$CLIENT_PROCESS_FILE")
            rm -- "${APPDATA_PATH}/Process_${CLIENT_PROCESS_FILE}.cproc" &>/dev/null
        fi
    done
    [ ${#TERMINATED_PROCESS_IDS[@]} -ne 0 ] && dprint "终止进程: ${TERMINATED_PROCESS_IDS[*]}"
}

# 函数名：killClientCleanExit
# 角色：清理退出
function killClientCleanExit() {
    killClient
    cleanProcesses
    exit 1
}

# 函数名：earlyDispatch
# 角色：早期分发命令
function earlyDispatch() {
    if [[ -z "${1:-}" ]] || [[ "$1" == "help" ]]; then
        printHelp
        exit 0
    elif [[ "$1" == "kill" ]]; then
        killClient
        cleanProcesses
        exit 0
    elif [[ "$1" == "clean" ]]; then
        cleanProcesses
        exit 0
    fi
}

# 函数名：silentThrowExit
# 角色：静默抛出错误 (无弹窗)
function silentThrowExit() {
    local ERR_CODE="$1"
    local ERROR_MSG=""
    
    case "$ERR_CODE" in
        "$EC_MISSING_CONFIG")
            dprint "ERROR: 配置文件缺失: $CONFIG_PATH"
            ERROR_MSG="错误: 配置文件缺失\n\n请检查配置文件是否存在:\n$CONFIG_PATH"
            ;;
        "$EC_MISSING_CLIENT")
            dprint "ERROR: 客户端工具未安装"
            ERROR_MSG="错误: 客户端工具未安装\n\n请安装 xfreerdp:\nsudo apt-get install freerdp2-x11"
            ;;
        "$EC_NOT_IN_GROUP")
            dprint "ERROR: 用户组权限不足"
            ERROR_MSG="错误: 用户组权限不足\n\n请确保用户在 libvirt 和 kvm 组中"
            ;;
        "$EC_FAIL_START")
            dprint "ERROR: 服务启动失败"
            ERROR_MSG="错误: 服务启动失败\n\n请检查虚拟机状态和配置"
            ;;
        "$EC_BAD_PORT")
            dprint "ERROR: 连接端口不可达: $WS_PORT"
            ERROR_MSG="错误: 无法连接到虚拟机\n\n端口: $WS_PORT\nIP: $WS_IP\n\n请检查虚拟机是否正在运行"
            ;;
        "$EC_UNSUPPORTED_APP")
            dprint "ERROR: 不支持的应用程序"
            ERROR_MSG="错误: 不支持的应用程序\n\n请使用 ./workspace-app.sh list 查看可用应用"
            ;;
        "$EC_INVALID_FLAVOR")
            dprint "ERROR: 无效的后端类型: $WAFLAVOR"
            ERROR_MSG="错误: 无效的后端类型: $WAFLAVOR"
            ;;
        "$EC_NO_DISPLAY")
            dprint "ERROR: 未在 X11 图形环境中运行"
            ERROR_MSG="错误: 未在 X11 图形环境中运行\n\n解决方案:\n1. 在本地桌面环境中运行\n2. 确保已登录到图形会话\n3. 如果通过 SSH 连接，使用 -X 参数: ssh -X user@host"
            ;;
        *)
            dprint "ERROR: 未知错误代码 $ERR_CODE"
            ERROR_MSG="错误: 未知错误 ($ERR_CODE)"
            ;;
    esac
    
    # 尝试显示 GUI 错误对话框
    if [ -n "$ERROR_MSG" ] && [ "$ERR_CODE" != "$EC_NO_DISPLAY" ]; then
        if command -v zenity &>/dev/null; then
            zenity --error \
                --title="工作区启动器" \
                --text="$ERROR_MSG" \
                --no-wrap 2>/dev/null
        elif command -v kdialog &>/dev/null; then
            kdialog --error "$ERROR_MSG" 2>/dev/null
        elif command -v xmessage &>/dev/null; then
            xmessage -center "$ERROR_MSG" 2>/dev/null
        fi
    fi
    
    exit "$ERR_CODE"
}

# 函数名：dprint
# 角色：日志打印 (无 WinApps/RDP 信息)
function dprint() {
    # 仅记录日志，不输出到终端，保持静默
    echo "[$(date '+%Y-%m-%d %H:%M:%S')-$RUNID] $1" >>"$LOG_PATH" 2>&1
}

# 函数名：printHelp
# 角色：打印帮助
function printHelp() {
    local script_name
    script_name="$(basename "$0")"
    echo "Workspace Launcher 脚本"
    echo "用法: $script_name [选项] [应用]"
    echo "选项:"
    echo "  help     显示此帮助信息"
    echo "  kill     终止所有会话"
    echo "  clean    清理残留文件"
    echo ""
    echo "应用:"
    echo "  启动预配置的应用程序"
}

# 函数名：loadConfig
# 角色：加载配置
function loadConfig() {
    if [ -f "$CONFIG_PATH" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_PATH"
        dprint "配置加载完成"
        if [ -z "$WS_IP" ] || [ -z "$WS_USER" ] || [ -z "$WS_PASS" ]; then
            silentThrowExit $EC_MISSING_CONFIG
        fi
        # 验证虚拟机名称
        if [ -z "$VM_NAME" ]; then
            dprint "警告: VM_NAME 未配置，使用默认值 WorkspaceVM"
            VM_NAME="WorkspaceVM"
        fi
        # 验证端口（静默设置默认值）
        if [ -z "$WS_PORT" ]; then
            WS_PORT=3389
        fi
    else
        silentThrowExit $EC_MISSING_CONFIG
    fi
}

# 函数名：getClientCommand
# 角色：获取客户端命令
function getClientCommand() {
    local CLIENT_MAJOR_VERSION=""
    
    # 检查 xfreerdp（简化版本检测）
    if command -v xfreerdp &>/dev/null; then
        CLIENT_COMMAND="xfreerdp"
        return
    fi
    
    # 检查 flatpak
    if command -v flatpak &>/dev/null && flatpak list --columns=application | grep -q "^com.freerdp.FreeRDP$"; then
        CLIENT_COMMAND="flatpak run --command=xfreerdp com.freerdp.FreeRDP"
        return
    fi
    
    silentThrowExit "$EC_MISSING_CLIENT"
}

# 函数名：checkVMRunning
# 角色：检查虚拟机状态 (Libvirt)
function checkVMRunning() {
    local EXIT_STATUS=0
    local TIME_ELAPSED=0
    local TIME_LIMIT=60
    local TIME_INTERVAL=5

    if virsh list --all --name | grep -Fxq "$VM_NAME"; then
        if virsh list --state-shutoff --name | grep -Fxq "$VM_NAME"; then
            dprint "VM 已关机. 启动中..."
            virsh start "$VM_NAME" &>/dev/null || EXIT_STATUS=$EC_FAIL_START
            NEEDED_BOOT=true
        elif virsh list --state-paused --name | grep -Fxq "$VM_NAME"; then
            dprint "VM 已暂停. 恢复中..."
            virsh resume "$VM_NAME" &>/dev/null || EXIT_STATUS=$EC_FAIL_RESUME
        elif virsh list --state-other --name | grep -Fxq "$VM_NAME"; then
            # 处理崩溃或正在关闭的状态
            local DOM_STATE
            DOM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null)
            if [[ "$DOM_STATE" == "crashed" ]]; then
                dprint "VM 崩溃. 尝试重启..."
                virsh destroy "$VM_NAME" &>/dev/null || EXIT_STATUS=$EC_FAIL_DESTROY
                virsh start "$VM_NAME" &>/dev/null || EXIT_STATUS=$EC_FAIL_START
                NEEDED_BOOT=true
            elif [[ "$DOM_STATE" == "in shutdown" ]]; then
                dprint "VM 正在关闭. 等待..."
                EXIT_STATUS=$EC_SD_TIMEOUT
                # 等待逻辑...
            fi
        fi
    else
        EXIT_STATUS=$EC_NOT_EXIST
    fi

    [ "$EXIT_STATUS" -ne 0 ] && silentThrowExit "$EXIT_STATUS"

    # 等待 VM 就绪
    if [[ "$NEEDED_BOOT" == "true" ]]; then
        dprint "等待 VM 就绪..."
        while (( TIME_ELAPSED < BOOT_TIMEOUT )); do
            if virsh list --state-running --name | grep -Fxq "$VM_NAME"; then
                # 检查端口
                if timeout 1 bash -c ">/dev/tcp/$WS_IP/$WS_PORT" 2>/dev/null; then
                    dprint "VM 已就绪"
                    sleep 10 # 额外缓冲
                    break
                fi
            fi
            sleep 5
            TIME_ELAPSED=$((TIME_ELAPSED + 5))
        done
        (( TIME_ELAPSED >= BOOT_TIMEOUT )) && silentThrowExit $EC_FAIL_START
    fi
}

# 函数名：checkDisplay
# 角色：检查X11图形环境
function checkDisplay() {
    if [ -z "$DISPLAY" ]; then
        dprint "ERROR: 未在 X11 图形环境中运行"
        
        # 尝试显示 GUI 错误对话框
        if command -v zenity &>/dev/null; then
            zenity --error \
                --title="工作区启动器" \
                --text="错误: 此脚本需要在 X11 图形环境中运行\n\n解决方案:\n1. 在本地桌面环境中运行\n2. 确保已登录到图形会话\n3. 如果通过 SSH 连接，使用 -X 参数: ssh -X user@host" \
                --no-wrap 2>/dev/null
        elif command -v kdialog &>/dev/null; then
            kdialog --error "错误: 此脚本需要在 X11 图形环境中运行\n\n解决方案:\n1. 在本地桌面环境中运行\n2. 确保已登录到图形会话\n3. 如果通过 SSH 连接，使用 -X 参数: ssh -X user@host" 2>/dev/null
        elif command -v xmessage &>/dev/null; then
            xmessage -center "错误: 此脚本需要在 X11 图形环境中运行\n\n解决方案:\n1. 在本地桌面环境中运行\n2. 确保已登录到图形会话\n3. 如果通过 SSH 连接，使用 -X 参数: ssh -X user@host" 2>/dev/null
        fi
        
        # 输出到日志和终端
        echo "错误: 此脚本需要在 X11 图形环境中运行"
        echo ""  
        echo "解决方案:"
        echo "1. 在本地终端中运行（不通过SSH）"
        echo "2. 使用 SSH X11 转发: ssh -X user@host"
        echo "3. 设置 DISPLAY 环境变量: export DISPLAY=:0"
        
        silentThrowExit $EC_NO_DISPLAY
    fi
}

# 函数名：checkPortOpen
# 角色：检查端口
function checkPortOpen() {
    if [ -z "$WS_IP" ]; then
        silentThrowExit $EC_NO_IP
    fi
    timeout 10 nc -z "$WS_IP" "$WS_PORT" &>/dev/null || silentThrowExit "$EC_BAD_PORT"
}

# 函数名：runCommand
# 角色：运行命令
function runCommand() {
    local ICON=""
    local FILE_PATH=""
    local DRIVE_ARGS=""

    # 处理预配置应用
    if [ -e "${APPDATA_PATH}/${1}/info" ]; then
        # shellcheck source=/dev/null
        source "${APPDATA_PATH}/${1}/info"
    else
        silentThrowExit "$EC_UNSUPPORTED_APP"
    fi

    # 构建驱动映射参数（从info文件读取或使用默认值）
    if [[ -n "${WIN_DRIVES+x}" ]] && [[ -n "$WIN_DRIVES" ]]; then
        # 使用应用配置中的驱动映射
        local drive_array
        IFS=',' read -ra drive_array <<< "$WIN_DRIVES"
        for drive_config in "${drive_array[@]}"; do
            local drive_name=$(echo "$drive_config" | cut -d':' -f1)
            local drive_path=$(echo "$drive_config" | cut -d':' -f2-)
            if [[ -d "$drive_path" ]]; then
                DRIVE_ARGS+=" /drive:${drive_name},${drive_path}"
                dprint "驱动映射: ${drive_name} -> ${drive_path}"
            else
                dprint "警告: 驱动路径不存在: ${drive_path}"
            fi
        done
    else
        # 使用默认驱动映射
        DRIVE_ARGS=" /drive:LinuxHome,$HOME /drive:Workspace,${SCRIPT_DIR_PATH}"
        dprint "使用默认驱动映射"
    fi

    if [ -z "$2" ]; then
        dprint "启动应用: $WIN_EXECUTABLE"
        # dprint "启动参数: $CLIENT_COMMAND /v:$WS_IP:$WS_PORT /u:$WS_USER /p:*** /app:$WIN_EXECUTABLE${DRIVE_ARGS} +clipboard"
        $CLIENT_COMMAND \
        /v:"$WS_IP:$WS_PORT" \
        /u:"$WS_USER" \
        /p:"$WS_PASS" \
        /app:program:"$WIN_EXECUTABLE" \
        ${DRIVE_ARGS} \
        +clipboard &>/dev/null &

        CLIENT_PID=$!
    else
        # 文件打开功能暂不支持（/app-cmd 参数可能在某些版本中不可用）
        dprint "启动应用: $WIN_EXECUTABLE" 
        dprint "文件参数: $2"
        dprint "注意: 文件参数暂不支持，将通过磁盘重定向访问文件"
        # dprint "启动参数: $CLIENT_COMMAND /v:$WS_IP:$WS_PORT /u:$WS_USER /p:*** /app:$WIN_EXECUTABLE${DRIVE_ARGS} +clipboard"
        $CLIENT_COMMAND \
        /v:"$WS_IP:$WS_PORT" \
        /u:"$WS_USER" \
        /p:"$WS_PASS" \
        /app:program:"$WIN_EXECUTABLE" \
        ${DRIVE_ARGS} \
        +clipboard &>/dev/null &

        CLIENT_PID=$!
    fi

    if [ "$CLIENT_PID" -ne -1 ]; then
        touch "${APPDATA_PATH}/Process_${CLIENT_PID}.cproc"
        wait "$CLIENT_PID"
        rm -f "${APPDATA_PATH}/Process_${CLIENT_PID}.cproc"
        dprint "会话结束"
    fi
}

# 函数名：checkIdle
# 角色：检查空闲并挂起
function checkIdle() {
    if [ "$AUTOPAUSE" = "on" ] && [ "$WAFLAVOR" = "libvirt" ]; then
        local TIME_INTERVAL=10
        local TIME_ELAPSED=0
        local SUSPEND_VM=0

        if ! ls "$APPDATA_PATH"/Process_*.cproc &>/dev/null; then
            SUSPEND_VM=1
            while (( TIME_ELAPSED < AUTOPAUSE_TIME )); do
                if ls "$APPDATA_PATH"/Process_*.cproc &>/dev/null; then
                    SUSPEND_VM=0
                    break
                fi
                sleep $TIME_INTERVAL
                TIME_ELAPSED=$((TIME_ELAPSED + TIME_INTERVAL))
            done
        fi

        if [ "$SUSPEND_VM" -eq 1 ]; then
            dprint "空闲超时. 挂起虚拟机."
            virsh suspend "$VM_NAME" &>/dev/null
        fi
    fi
}

# 函数名：timeSync
# 角色：时间同步检测
function timeSync() {
    local CURRENT_TIME CURRENT_UPTIME STORED_TIME=0 STORED_UPTIME=0 EXPECTED_UPTIME UPTIME_DIFF
    CURRENT_TIME=$(date +%s)
    CURRENT_UPTIME=$(awk '{print int($1)}' /proc/uptime)

    if [ -f "$SLEEP_DETECT_PATH" ]; then
        STORED_TIME=$(head -n1 "$SLEEP_DETECT_PATH" 2>/dev/null || echo 0)
        STORED_UPTIME=$(tail -n1 "$SLEEP_DETECT_PATH" 2>/dev/null || echo 0)
    fi

    if [ "$STORED_TIME" -gt 0 ] && [ "$STORED_UPTIME" -gt 0 ]; then
        EXPECTED_UPTIME=$((STORED_UPTIME + CURRENT_TIME - STORED_TIME))
        UPTIME_DIFF=$((EXPECTED_UPTIME - CURRENT_UPTIME))
        if [[ "$UPTIME_DIFF" -gt 30 && ! -f "$SLEEP_MARKER" ]]; then
            dprint "检测到系统休眠. 创建同步标记."
            touch "$SLEEP_MARKER"
        fi
    fi
    {
        echo "$CURRENT_TIME"
        echo "$CURRENT_UPTIME"
    } > "$SLEEP_DETECT_PATH"
}

### MAIN LOGIC ###
mkdir -p "$APPDATA_PATH"
dprint "=== 启动器开始 ==="

earlyDispatch "$@"
dprint "参数: $*"

# 只有在文件不存在时才创建默认配置
if [ ! -f "$CONFIG_PATH" ]; then
    cat > "$CONFIG_PATH" << EOF
# Workspace 配置文件
# 虚拟机名称
VM_NAME="WorkspaceVM"

# RDP 连接信息
WS_IP="192.168.122.28"
WS_USER="sclead"
WS_PASS="sclead"
EOF
    dprint "已创建默认配置文件: $CONFIG_PATH"
    echo "默认配置已生成，请编辑 $CONFIG_PATH 后重新运行。"
    exit 1
fi

loadConfig
getClientCommand
cleanProcesses

# 检查X11图形环境（在help/kill/clean之后）
if [[ "$1" != "help" ]] && [[ "$1" != "kill" ]] && [[ "$1" != "clean" ]]; then
    # 检查应用是否存在
    if [ ! -e "${APPDATA_PATH}/${1}/info" ]; then
        silentThrowExit "$EC_UNSUPPORTED_APP"
    fi
    checkDisplay
fi

# 处理密码
RDP_PASSWORD_ARG="/p:$WS_PASS"
if [[ ! -z "$WS_ASKPASS" ]]; then
    export FREERDP_ASKPASS="$WS_ASKPASS"
    unset RDP_PASSWORD_ARG
fi

# 后端处理
if [ "$WAFLAVOR" = "libvirt" ]; then
    checkVMRunning
else
    silentThrowExit "$EC_INVALID_FLAVOR"
fi

checkPortOpen
timeSync
runCommand "$@"

if [[ "$AUTOPAUSE" == "on" ]]; then
    checkIdle
fi

dprint "=== 启动器结束 ==="