#! /bin/bash

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

AURORA_PATH="$HOME/aurora"

function check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 请使用 root 账号运行该脚本！" && exit 1
}

function check_system() {
    source '/etc/os-release'
    ARCH=$(uname -m)
    [[ $ARCH == "x86_64" || $ARCH == "aarch64" ]] || (echo -e "${Error} 极光面板仅支持安装在 X64 或 ARM64 架构的机器上！" && exit 1)
    if [ $ID = "centos" ]; then
        OS_FAMILY="centos"
        UPDATE="yum makecache -q -y"
        INSTALL="yum install -q -y"
    elif  [ $ID = "debian" ] || [ $ID = "ubuntu" ]; then
        OS_FAMILY="debian"
        UPDATE="apt update -qq -y"
        INSTALL="apt install -qq -y"
    else
        echo -e "${Error} 系统 $ID $VERSION_ID 暂不支持一键脚本，请尝试手动安装！" && exit 1
    fi
}

function install_software() {
    [[ -z $1 ]] || (type $1 > /dev/null 2>&1 || (echo -e "开始安装依赖 $1 ..." && $INSTALL $1) || ($UPDATE && $INSTALL $1))
}

function install_docker() {
    if ! type docker > /dev/null 2>&1; then
        curl -fsSL "https://get.docker.com" | bash -s docker --mirror Aliyun
        systemctl enable --now docker
    fi
}

function install_docker_compose() {
    if ! type docker-compose > /dev/null 2>&1; then
        curl -fsSL "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
}

function install_all() {
    install_software wget
    install_software curl
    install_docker
    install_docker_compose
}

function install() {
    install_all
    [[ -n $(docker ps | grep aurora) ]] && echo -e "${Tip} 极光面板已经安装，且正在运行！" && exit 0
    [ -d ${AURORA_PATH} ] || mkdir -p ${AURORA_PATH}
    cd ${AURORA_PATH} && wget "https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose.yml" -O docker-compose.yml
    docker-compose up -d && docker-compose exec backend python app/initial_data.py && \
    (echo -e "${Info} 极光面板安装成功，已启动！" && exit 0) || (echo -e "${Error} 极光面板安装失败！" && exit 1)
}

function check_install() {
    [ -f "$HOME/aurora/docker-compose.yml" ] || (echo -e "${Tip} 未检测到已经安装极光面板，请先安装！" && exit 1)
}

function update() {
    check_install || exit 1
    install_all
    cd ${AURORA_PATH} && wget "https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose.yml" -O docker-compose.yml
    docker-compose pull && docker-compose down --remove-orphans && docker-compose up -d && \
    (echo -e "${Info} 极光面板更新成功！" && exit 0) || (echo -e "${Error} 极光面板更新失败！" && exit 1)
}

function uninstall() {
    [ -f "$HOME/aurora/docker-compose.yml" ] || (echo -e "${Tip} 未检测到已经安装极光面板！" && exit 0)
    cd ${AURORA_PATH}
    [[ -n $(docker ps | grep aurora) ]] && docker-compose down
    docker volume rm aurora_db-data && docker volume rm aurora_app-data && \
    (rm -rf ${AURORA_PATH} && echo -e "${Info} 卸载成功！" && exit 0) || (echo -e "${Error} 卸载失败！" && exit 1)
}

function no_run_tip() {
    LEVEL=$1 && [[ -z $LEVEL || $LEVEL != ${Info} || $LEVEL != ${Tip} || $LEVEL != ${Error} ]] && LEVEL=${Tip}
    TIPS=$2 && [[ -z $TIPS ]] && TIPS="极光面板未在运行！"
    [[ -z $(docker ps | grep aurora) ]] && echo -e "${LEVEL} $TIPS"
}

function start() {
    check_install || exit 1
    [[ -n $(docker ps | grep aurora) ]] && echo -e "${Info} 极光面板正在运行" && exit 0
    cd ${AURORA_PATH} && docker-compose up -d && echo -e "${Info} 启动成功！" || echo -e "${Error} 启动失败！"
}

function stop() {
    check_install || exit 1
    no_run_tip ${Info} && exit 0
    cd ${AURORA_PATH} && docker-compose down && echo -e "${Info} 停止成功！" || echo -e "${Error} 停止失败！"
}

function restart() {
    check_install || exit 1
    no_run_tip ${Tip} "极光面板未在运行，请直接启动！" && exit 0
    cd ${AURORA_PATH} && docker-compose restart && echo -e "${Info} 重启成功！" || echo -e "${Error} 重启失败！"
}

function backend_logs() {
    check_install || exit 1
    no_run_tip && exit 1
    cd ${AURORA_PATH} && docker-compose logs -f --tail="100" backend worker
}

function frontend_logs() {
    check_install || exit 1
    no_run_tip && exit 1
    cd ${AURORA_PATH} && docker-compose logs -f --tail="100" frontend
}

function all_logs() {
    check_install || exit 1
    no_run_tip && exit 1
    cd ${AURORA_PATH} && docker-compose logs -f --tail="100"
}

function export_logs() {
    check_install || exit 1
    no_run_tip && exit 1
    cd ${AURORA_PATH} && docker-compose logs > logs && \
    echo -e "${Info} 日志导出成功：${AURORA_PATH}/logs" || echo -e "${Error} 日志导出失败！"
}

function backup() {
    check_install || exit 1
    [[ -z $(docker ps | grep aurora | grep postgres) ]] && echo -e "${Tip} 极光面板未在运行，请先启动！" && exit 1
    DB_USER=$(grep POSTGRES_USER ${AURORA_PATH}/docker-compose.yml | awk '{print $2}')
    [[ -z $DB_USER ]] && DB_USER="aurora"
    DB_NAME=$(grep POSTGRES_DB ${AURORA_PATH}/docker-compose.yml | awk '{print $2}')
    [[ -z $DB_NAME ]] && DB_NAME="aurora"
    cd ${AURORA_PATH} && docker-compose exec postgres pg_dump -d $DB_NAME -U $DB_USER -c > data.sql && \
    echo -e "${Info} 数据库导出成功：${AURORA_PATH}/data.sql" || echo -e "${Error} 数据库导出失败！"
}

function restore() {
    check_install || exit 1
    echo -e "${Tip} 高危操作，请手动执行！" && exit 0
}

function add_superu() {
    check_install || exit 1
    [[ -z $(docker ps | grep aurora | grep backend) ]] && echo -e "${Tip} 极光面板未在运行，请先启动！" && exit 1
    cd ${AURORA_PATH} && docker-compose exec backend python app/initial_data.py
}

function welcome_aurora() {
    check_root
    check_system
    echo -e "${Green_font_prefix}
            极光面板 一键脚本
    --------------------------------
    1.  安装 极光面板
    2.  更新 极光面板
    3.  卸载 极光面板
    ————————————
    4.  启动 极光面板
    5.  停止 极光面板
    6.  重启 极光面板
    ————————————
    7.  查看 后端实时日志
    8.  查看 前端实时日志
    9.  查看 全部实时日志
    10. 导出 全部日志
    ————————————
    11. 备份 数据库
    12. 还原 数据库
    13. 添加 管理员用户
    ————————————
    0.  退出脚本
    ————————————
    ${Font_color_suffix}"
    read -r -e -p " 请输入数字 [1-13]: " num && echo
    case "$num" in
        1)
            install
            ;;
        2)
            update
            ;;
        3)
            uninstall
            ;;
        4)
            start
            ;;
        5)
            stop
            ;;
        6)
            restart
            ;;
        7)
            backend_logs
            ;;
        8)
            frontend_logs
            ;;
        9)
            all_logs
            ;;
        10)
            export_logs
            ;;
        11)
            backup
            ;;
        12)
            restore
            ;;
        13)
            add_superu
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${Error} 请输入正确数字 [1-13]"
            ;;
    esac
}

welcome_aurora
