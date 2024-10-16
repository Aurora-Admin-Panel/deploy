#! /bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

Green_font_prefix="\033[32m"
Green_background_prefix="\033[42;37m"
Red_font_prefix="\033[31m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

[[ $EUID != 0 ]] && echo -e "${Error} 请使用 root 账号运行该脚本！" && exit 1

while [[ $# -ge 1 ]]; do
    case $1 in
        --dev)
            AURORA_VERSION="DEV"
            shift
            ;;
        *)
            echo -e "${Error} 请检查脚本输入的参数是否正确！"
            exit 1
    esac
done

INSTALL_VERSION="1.0.0"
[[ -z "$HOME" ]] && echo -e "${Error} 家目录检查失败！" && exit 1
AURORA_HOME="$HOME/aurora"
AURORA_HOME_BACKUP="$HOME/aurora_backup"
AURORA_DOCKER_YML=${AURORA_HOME}/docker-compose.yml
AURORA_DOCKER_YML_TEMP=${AURORA_HOME}/docker-compose.yml.tmp
GITHUB_RAW_URL="raw.githubusercontent.com"
GITHUB_URL="github.com"
AURORA_GITHUB="Aurora-Admin-Panel"
AURORA_YML_URL="https://${GITHUB_RAW_URL}/${AURORA_GITHUB}/deploy/main/docker-compose.yml"
AURORA_DEV_YML_URL="https://${GITHUB_RAW_URL}/${AURORA_GITHUB}/deploy/main/docker-compose-dev.yml"
DOCKER_INSTALL_URL="https://get.docker.com"
DOCKER_COMPOSE_CMD='docker compose'
DOCKER_COMPOSE_URL="https://${GITHUB_URL}/docker/compose/releases/download/v2.29.7/docker-compose-$(uname -s)-$(uname -m)"

AURORA_DEF_IP=""
AURORA_DEF_PORT=8000
AURORA_DEF_TRAFF_MIN=10
AURORA_DEF_DDNS_MIN=2
AURORA_IP6TABLES_MASQ_COMMENT='aurora-docker-ipv6-support'

function check_system() {
    source '/etc/os-release'
    ARCH=$(uname -m)
    [[ $ARCH == "x86_64" || $ARCH == "aarch64" ]] || \
    (echo -e "${Error} 极光面板仅支持安装在 X64 或 ARM64 架构的机器上！" && exit 1)
    if [[ $ID = "centos" ]]; then
        OS_FAMILY="centos"
        UPDATE="yum makecache -q -y"
        INSTALL="yum install -q -y"
    elif [[ $ID = "debian" || $ID = "ubuntu" ]]; then
        OS_FAMILY="debian"
        UPDATE="apt update -qq -y"
        INSTALL="apt install -qq -y"
    elif [[ $ID = "alpine" ]]; then
        OS_FAMILY="alpine"
        UPDATE="apk update"
        INSTALL="apk add"
    else
        echo -e "${Error} 系统 $ID $VERSION_ID 暂不支持一键脚本，请尝试手动安装！" && exit 1
    fi
}

function check_docker_compose() {
    if docker compose > /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD='docker compose'
    elif docker-compose > /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD='docker-compose'
    else
        # 新安装的 docker 默认自带 compose 插件
        DOCKER_COMPOSE_CMD='docker compose'
    fi
}

function install_software() {
    [[ -z $1 ]] || \
    (type $1 > /dev/null 2>&1 || (echo -e "开始安装依赖 $1 ..." && $INSTALL $1) || ($UPDATE && $INSTALL $1))
}

function install_docker() {
    if [[ $OS_FAMILY = "centos" || $OS_FAMILY = "debian" ]]; then
        if ! docker > /dev/null 2>&1; then
            curl -fsSL ${DOCKER_INSTALL_URL} | bash -s docker
        fi
        systemctl enable --now docker && \
            while ! systemctl is-active --quiet docker; do sleep 3; done
    elif [[ $OS_FAMILY = "alpine" ]]; then
        if ! docker > /dev/null 2>&1; then
            ($INSTALL docker || ($UPDATE && $INSTALL docker))
        fi
        rc-update add docker boot && \
            service docker start && \
            while [[ -z $(service docker status | grep started) ]]; do sleep 3; done
    fi
}

function install_docker_compose() {
    if ! docker compose > /dev/null 2>&1; then
        curl -fsSL ${DOCKER_COMPOSE_URL} -o /usr/local/bin/docker-compose && \
        chmod +x /usr/local/bin/docker-compose && \
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        # update docker compose cmd
        check_docker_compose
    fi
}

function install_all() {
    install_software wget
    install_software curl
    install_docker
    install_docker_compose
}

function get_config() {
    echo -e "${Info} 正在下载最新配置文件 ..."
    [[ $AURORA_VERSION == "DEV" ]] && YML_URL=${AURORA_DEV_YML_URL} || YML_URL=${AURORA_YML_URL}
    wget -q $YML_URL -O ${AURORA_DOCKER_YML_TEMP}
    [[ -z $(grep aurora ${AURORA_DOCKER_YML_TEMP}) ]] && echo -e "${Error} 配置文件下载失败，请检查网络连接是否正常！" && exit 1
    mv -f ${AURORA_DOCKER_YML_TEMP} ${AURORA_DOCKER_YML}
}

function check_install() {
    [ -f ${AURORA_DOCKER_YML} ] || (echo -e "${Tip} 未检测到已经安装极光面板，请先安装！" && exit 1)
}

function match_config() {
    [[ -z $1 ]] || TEMP=$(cat ${AURORA_DOCKER_YML} | awk -v name="$1" '{ if ( $0 ~ name ){ print $2; } }' | head -n 1)
    [[ -z $TEMP ]] && [[ -n $2 ]] && echo $2 || echo $TEMP
}

function read_config() {
    ENABLE_SENTRY=$(match_config ENABLE_SENTRY \'no\')
    TRAFFIC_INTERVAL_SECONDS=$(match_config TRAFFIC_INTERVAL_SECONDS 600)
    DDNS_INTERVAL_SECONDS=$(match_config DDNS_INTERVAL_SECONDS 120)
    check_ipv6_enabled && ENABLE_IPV6=true || ENABLE_IPV6=false
}

function set_config() {
    [[ -z $ENABLE_SENTRY ]] || sed -i "s/ENABLE_SENTRY:.*$/ENABLE_SENTRY: $ENABLE_SENTRY/" ${AURORA_DOCKER_YML}
    [[ -z $TRAFFIC_INTERVAL_SECONDS ]] || sed -i "s/TRAFFIC_INTERVAL_SECONDS:.*$/TRAFFIC_INTERVAL_SECONDS: $TRAFFIC_INTERVAL_SECONDS/" ${AURORA_DOCKER_YML}
    [[ -z $DDNS_INTERVAL_SECONDS ]] || sed -i "s/DDNS_INTERVAL_SECONDS:.*$/DDNS_INTERVAL_SECONDS: $DDNS_INTERVAL_SECONDS/" ${AURORA_DOCKER_YML}
}

function read_port() {
    IP=$(grep -A 1 port ${AURORA_DOCKER_YML} | grep -Eo "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)")
    [[ -z $IP ]] && PORT=$(grep -A 1 port ${AURORA_DOCKER_YML} | grep -Eo "[[:digit:]]+:" | grep -Eo "[[:digit:]]+") || \
    PORT=$(grep -A 1 port ${AURORA_DOCKER_YML} | grep -Eo ":[[:digit:]]+:" | grep -Eo "[[:digit:]]+")
    [[ -z $PORT ]] && echo -e "${Error} 未检测到旧端口号，请检查配置文件是否正确！" && exit 1
}

function set_port() {
    [[ -z $1 ]] && PORT=${AURORA_DEF_PORT} || PORT=$1
    NEW_PORT=$(echo $2 | grep -Eo "[[:digit:]]+")
    [[ -z $NEW_PORT ]] && echo -e "${Error} 未检测到新端口号！" && exit 1
    [[ -z $IP ]] && sed -i "s/- $PORT:80/- $NEW_PORT:80/" ${AURORA_DOCKER_YML} || \
    (sed -i "s/- $PORT:80/- $IP:$NEW_PORT:80/" ${AURORA_DOCKER_YML} && \
    sed -i "s/- $IP:$PORT:80/- $IP:$NEW_PORT:80/" ${AURORA_DOCKER_YML})
}

function check_run() {
    LEVEL=$1 && [[ -z $LEVEL || $LEVEL != ${Info} || $LEVEL != ${Tip} || $LEVEL != ${Error} ]] && LEVEL=${Tip}
    TIPS=$2 && [[ -z $TIPS ]] && TIPS="极光面板未在运行！"
    [[ -z $(docker ps | grep aurora) ]] && echo -e "${LEVEL} $TIPS"
}


function change_port() {
    check_install || exit 1
    check_run && exit 1
    read_port
    echo -e "${Info} 旧端口号: $PORT"
    read -r -e -p "请输入新端口: " NEW_PORT
    set_port $PORT $NEW_PORT
    read_port
    [[ $PORT = $NEW_PORT ]] && cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD up -d && \
    echo -e "${Info} 端口修改成功！" || echo -e "${Error} 端口修改失败！"
}

function sec_to_min() {
    [[ -z $1 ]] || sec=$(echo $1 | grep -v "\." | grep -Eo "[[:digit:]]+")
    [[ -z $sec ]] || ((min=$sec/60))
    echo $min
}

function min_to_sec() {
    [[ -z $1 ]] || min=$(echo $1 | grep -v "\." | grep -Eo "[[:digit:]]+")
    [[ -z $min ]] || ((sec=$min*60))
    echo $sec
}

function echo_config() {
    [[ -z $IP ]] || echo -e "${Info} 面板监听地址: $IP"
    [[ -z $PORT ]] || echo -e "${Info} 面板监听端口: $PORT"
    [[ -z $ENABLE_SENTRY ]] || echo -e "${Info} 开启错误跟踪: $ENABLE_SENTRY"
    [[ -z $TRAFFIC_INTERVAL_SECONDS ]] || echo -e "${Info} 流量同步周期: $(sec_to_min $TRAFFIC_INTERVAL_SECONDS) 分钟"
    [[ -z $DDNS_INTERVAL_SECONDS ]] || echo -e "${Info} DDNS同步周期: $(sec_to_min $DDNS_INTERVAL_SECONDS) 分钟"
    $ENABLE_IPV6 && echo -e "${Info} 已开启 IPV6 支持" || echo -e "${Info} 未开启 IPV6 支持"
}

function install() {
    install_all
    [[ -n $(docker ps | grep aurora) ]] && echo -e "${Tip} 极光面板已经安装，且正在运行！" && exit 0
    [[ -d ${AURORA_HOME} ]] || mkdir -p ${AURORA_HOME}
    cd ${AURORA_HOME}
    get_config || exit 1
    echo "-----------------------------------"
    read_config
    read_port
    echo_config
    echo "-----------------------------------"
    [[ ! -d "$HOME"/.ssh ]] && mkdir -p "$HOME"/.ssh
    # avoid docker creating a directory automatically
    [[ ! -f "$HOME"/.ssh/id_rsa ]] && touch "$HOME"/.ssh/id_rsa
    $DOCKER_COMPOSE_CMD up -d && $DOCKER_COMPOSE_CMD exec backend python app/initial_data.py && \
    (echo -e "${Info} 极光面板安装成功，已启动！" && exit 0) || (echo -e "${Error} 极光面板安装失败！" && exit 1)
}

function update() {
    check_install && install_all || exit 1
    cd ${AURORA_HOME}
    echo -e "${Info} 同步旧配置文件中 ..."
    echo "-----------------------------------"
    read_config
    read_port
    echo_config
    echo "-----------------------------------"
    get_config || exit 1
    set_config
    set_port ${AURORA_DEF_PORT} $PORT
    echo -e "${Info} 同步新配置文件完成！"
    [[ -z $(docker ps | grep aurora | grep postgres) ]] && \
        echo -e "${Error} 请先运行极光面板，以保证更新前完成自动备份旧数据库！" && exit 1 || \
        (echo -e "${Tip} 正在备份旧数据库，如果更新后出现问题，请回退旧版本并恢复旧数据库！" && backup)
    $DOCKER_COMPOSE_CMD pull
    if $ENABLE_IPV6 ; then
        enable_ipv6
    else
        recreate
    fi
    OLD_IMG_IDS=$(docker images | grep aurora | grep -v latest | awk '{ print $3; }')
    [[ -z $OLD_IMG_IDS ]] || (docker image rm $OLD_IMG_IDS && echo -e "${Info} 旧版镜像清理完成！")
    $DOCKER_COMPOSE_CMD up -d && \
        (echo -e "${Info} 极光面板更新成功！" && exit 0) || (echo -e "${Error} 极光面板更新失败！" && exit 1)
}

function backup_data_before_uninstall(){
    if [ ! -d ${AURORA_HOME_BACKUP} ]; then
        mkdir ${AURORA_HOME_BACKUP}
    fi
    cp -f ${AURORA_HOME}/data-*.sql ${AURORA_HOME_BACKUP}/
    echo -e "${Tip} 已有的数据库备份文件已移动到备份目录：${AURORA_HOME_BACKUP}" && \
    echo -e "${Tip} 如果不需要备份，可自行删除文件 rm -rf ${AURORA_HOME_BACKUP}"
}

function uninstall() {
    [ -f ${AURORA_DOCKER_YML} ] || (echo -e "${Tip} 未检测到已经安装极光面板！" && exit 0)
    [[ -n $(docker ps | grep aurora | grep postgres) ]] && \
    echo -e "${Tip} 正在备份数据库，如果意外卸载请重新安装面板并恢复数据库！" && backup
    backup_data_before_uninstall
    cd ${AURORA_HOME}
    [[ -n $(docker ps | grep aurora) ]] && $DOCKER_COMPOSE_CMD down
    OLD_IMG_IDS=$(docker images | grep aurora | awk '{ print $3; }')
    [[ -z $OLD_IMG_IDS ]] || (docker image rm $OLD_IMG_IDS && echo -e "${Info} 镜像清理完成！")
    docker volume rm aurora_db-data && docker volume rm aurora_app-data && \
    (rm -rf ${AURORA_HOME} && echo -e "${Info} 卸载成功！" && exit 0) || (echo -e "${Error} 卸载失败！" && exit 1)
}

function start() {
    check_install || exit 1
    [[ -n $(docker ps | grep aurora) ]] && echo -e "${Info} 极光面板正在运行" && exit 0
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD up -d && echo -e "${Info} 启动成功！" || echo -e "${Error} 启动失败！"
}

function stop() {
    check_install || exit 1
    check_run ${Info} && exit 0
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD down --remove-orphans && echo -e "${Info} 停止成功！" || echo -e "${Error} 停止失败！"
}

function restart() {
    check_install || exit 1
    check_run ${Tip} "极光面板未在运行，请直接启动！" && exit 0
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD restart && echo -e "${Info} 重启成功！" || echo -e "${Error} 重启失败！"
}

function recreate() {
    stop
    start
}

function backend_logs() {
    check_install || exit 1
    check_run && exit 1
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD logs -f --tail="100" backend worker
}

function frontend_logs() {
    check_install || exit 1
    check_run && exit 1
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD logs -f --tail="100" frontend
}

function all_logs() {
    check_install || exit 1
    check_run && exit 1
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD logs -f --tail="100"
}

function export_logs() {
    check_install || exit 1
    check_run && exit 1
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD logs > logs && \
    echo -e "${Info} 日志导出成功：${AURORA_HOME}/logs" || echo -e "${Error} 日志导出失败！"
}

function read_db_info() {
    DB_USER=$(grep POSTGRES_USER ${AURORA_DOCKER_YML} | awk '{print $2}')
    [[ -z $DB_USER ]] && DB_USER="aurora"
    DB_NAME=$(grep POSTGRES_DB ${AURORA_DOCKER_YML} | awk '{print $2}')
    [[ -z $DB_NAME ]] && DB_NAME="aurora"
}

function backup() {
    check_install || exit 1
    [[ -z $(docker ps | grep aurora | grep postgres) ]] && echo -e "${Tip} 极光面板未在运行，请先启动！" && exit 1
    BACKUP_FILE="data-$(date +%Y%m%d%H%M%S).sql"
    read_db_info
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD exec -T postgres pg_dump -d $DB_NAME -U $DB_USER -c > $BACKUP_FILE && \
    echo -e "${Info} 数据库备份成功：${AURORA_HOME}/$BACKUP_FILE" || echo -e "${Error} 数据库备份失败！"
}

function restore() {
    check_install || exit 1
    [[ -z $(docker ps | grep aurora | grep postgres) ]] && \
    echo -e "${Error} 请先运行极光面板，以保证还原前完成自动备份旧数据库！" && exit 1 || \
    (echo -e "${Tip} 正在备份旧数据库，如果还原后出现问题，请恢复旧数据库！" && backup)
    read -r -e -p "请输入需恢复的数据库文件路径: " BACKUP_FILE
    [[ ! -f $BACKUP_FILE ]] && echo -e "${Error} 无法找到数据库文件！" && exit 1
    cd ${AURORA_HOME}
    read_db_info
    docker stop $($DOCKER_COMPOSE_CMD ps | grep aurora | grep -v postgres | awk '{ print $1; }') && \
    $DOCKER_COMPOSE_CMD exec -T postgres psql -d $DB_NAME -U $DB_USER < $BACKUP_FILE > /dev/null && \
    $DOCKER_COMPOSE_CMD up -d && \
    echo -e "${Info} 数据库还原成功！" || echo -e "${Error} 数据库还原失败！"
}

function add_superu() {
    check_install || exit 1
    [[ -z $(docker ps | grep aurora | grep backend) ]] && echo -e "${Tip} 极光面板未在运行，请先启动！" && exit 1
    cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD exec backend python app/initial_data.py
}

function set_traffic_interval() {
    check_install || exit 1
    check_run && exit 1
    read_config
    echo -e "${Info} 旧流量同步间隔: $(sec_to_min $TRAFFIC_INTERVAL_SECONDS) 分钟"
    read -r -e -p "请输入新同步间隔 [分钟]: " NEW_TRAFFIC_INTERVAL_MIN
    NEW_TRAFFIC_INTERVAL_SEC=$(min_to_sec $NEW_TRAFFIC_INTERVAL_MIN)
    [[ -z $NEW_TRAFFIC_INTERVAL_SEC ]] && echo -e "${Error} 请输入整数分钟！" && exit 1 || \
    sed -i "s/TRAFFIC_INTERVAL_SECONDS:.*$/TRAFFIC_INTERVAL_SECONDS: $NEW_TRAFFIC_INTERVAL_SEC/" ${AURORA_DOCKER_YML}
    read_config
    [[ $TRAFFIC_INTERVAL_SECONDS = $NEW_TRAFFIC_INTERVAL_SEC ]] && cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD up -d && \
    echo -e "${Info} 流量同步间隔修改成功！" || echo -e "${Error} 流量同步间隔修改失败！"
}

function set_ddns_interval() {
    check_install || exit 1
    check_run && exit 1
    read_config
    echo -e "${Info} 旧DDNS同步间隔: $(sec_to_min $DDNS_INTERVAL_SECONDS) 分钟"
    read -r -e -p "请输入新同步间隔 [分钟]: " NEW_DDNS_INTERVAL_MIN
    NEW_DDNS_INTERVAL_SEC=$(min_to_sec $NEW_DDNS_INTERVAL_MIN)
    [[ -z $NEW_DDNS_INTERVAL_SEC ]] && echo -e "${Error} 请输入整数分钟！" && exit 1 || \
    sed -i "s/DDNS_INTERVAL_SECONDS:.*$/DDNS_INTERVAL_SECONDS: $NEW_DDNS_INTERVAL_SEC/" ${AURORA_DOCKER_YML}
    read_config
    [[ $DDNS_INTERVAL_SECONDS = $NEW_DDNS_INTERVAL_SEC ]] && cd ${AURORA_HOME} && $DOCKER_COMPOSE_CMD up -d && \
    echo -e "${Info} DDNS同步间隔修改成功！" || echo -e "${Error} DDNS同步间隔修改失败！"
}

function check_ipv6_enabled() {
    cat ${AURORA_DOCKER_YML} | grep '    enable_ipv6' | grep true > /dev/null 2>&1
}

function check_ip6tables_masq() {
    [[ -n $(ip6tables -t nat -nxvL | grep "${AURORA_IP6TABLES_MASQ_COMMENT}") ]] && echo -e "${Info} IPV6 MASQ 规则已存在！"
}

function enable_ipv6() {
    check_install || exit 1
    ip6tables -V > /dev/null || (echo -e "${Error} 请先安装 ip6tables！" && exit 1)
    IPV6_SUBNET=$(sed -n 's/^.*subnet:\s*\(.*\)$/\1/p' ${AURORA_DOCKER_YML})
    check_ip6tables_masq || (ip6tables -t nat -A POSTROUTING -s ${IPV6_SUBNET} -j MASQUERADE -m comment --comment "${AURORA_IP6TABLES_MASQ_COMMENT}" && \
        echo -e "${Info} 已添加 IPV6 MASQ 规则！")
    sed -i "s/    enable_ipv6:.*$/    enable_ipv6: true/" ${AURORA_DOCKER_YML}
    recreate
    check_ipv6_enabled && echo -e "${Info} 已开启 IPV6 支持！"
    echo -e "${Tip} 重启系统会导致 ip6tables 规则被重置，需要重新添加！"
}

function welcome_aurora() {
    check_system
    check_docker_compose
    echo -e "${Green_font_prefix}
            极光面板 一键脚本
    --------------------------------
    1.  安装 极光面板 ${FASTGIT} ${AURORA_VERSION}
    2.  更新 极光面板 ${FASTGIT} ${AURORA_VERSION}
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
    14. 修改 面板访问端口（默认 ${AURORA_DEF_PORT}）
    15. 修改 面板流量同步间隔（默认 ${AURORA_DEF_TRAFF_MIN} 分钟）
    16. 修改 DDNS同步间隔（默认 ${AURORA_DEF_DDNS_MIN} 分钟）
    17. 开启 IPV6 支持（需要本机支持 IPV6）
    ————————————
    0.  退出脚本
    ————————————
    ${Font_color_suffix}"
    read -r -e -p " 请输入数字 [1-16]: " num && echo
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
        14)
            change_port
            ;;
        15)
            set_traffic_interval
            ;;
        16)
            set_ddns_interval
            ;;
        17)
            enable_ipv6
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${Error} 请输入正确数字 [1-16]"
            ;;
    esac
}

welcome_aurora
