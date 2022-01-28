# 极光面板

## 这是什么？

这是一个多服务器端口租用管理面板，你可以添加多台服务器及端口，并将其分配给任意注册用户，租户则可以很方便地使用被分配的端口来完成各种操作，目前支持的端口功能（**以下功能均支持 AMD64 或 ARM64 架构运行**）：

- [iptables](https://www.netfilter.org/)
- [socat](http://www.dest-unreach.org/socat/)
- [gost](https://github.com/ginuerzh/gost)
- [ehco](https://github.com/Ehco1996/ehco)
- [realm](https://github.com/zephyrchien/realm)
- [v2ray](https://github.com/v2fly/v2ray-core)
- [brook](https://github.com/txthinking/brook)
- [iperf](https://iperf.fr)
- [wstunnel](https://github.com/erebe/wstunnel)
- [shadowsocks](https://github.com/shadowsocks)
- [tinyPortMapper](https://github.com/wangyu-/tinyPortMapper)
- [Prometheus Node Exporter](https://github.com/leishi1313/node_exporter)

### 面板服务器与被控机说明

**面板建议安装在单独的一台服务器上，建议安装配置为不低于单核 512M 内存的 VPS 中**，可以直接部署到本地。**被控机端无需做任何特别配置，只需保证面板服务器能够通过 ssh 连接至被控机即可。**

面板服务器在连接被控机的时候会检测被控机是否已经安装好 python （python 为被控机必须依赖），如果被控机上没安装会自动在被控机上通过 apt / yum 执行 python 安装（优先安装python3），如果被控机没有自带 python 且自动安装失败会导致面板显示被控机连接失败（表现为被控机连接状态持续转圈）。

#### 面板（主控机）支持进度：

- 操作系统
- [x] CentOS 7+
- [x] Debian 8+
- [x] Ubuntu 18+
- [x] Alpine Linux 3.15.0+ （请使用一键脚本安装）
- 虚拟平台
- [x] KVM
- [x] VMware
- [x] OVZ （需要 OVZ 支持 docker）
- CPU 架构
- [x] AMD64
- [x] ARM64

#### 中转机器（被控机）支持进度：

- 操作系统
- [x] CentOS 7+
- [x] Debian 8+
- [x] Ubuntu 18+
- [ ] Alpine Linux 3.15.0+  （正在开发中，目前仅支持部分 iptables 转发功能）
- [x] 其他操作系统如果支持 docker，可以参考下面的手动安装方法
- 虚拟平台
- [x] KVM
- [x] VMware
- [x] OVZ
- CPU 架构
- [x] AMD64
- [x] ARM64
- Linux init process
- [x] systemd
- [ ] SysVinit
- [ ] OpenRC

## 怎么跑起来？

## 一键脚本（推荐）

目前已支持一键安装、更新（自动同步旧配置）、卸载面板以及备份数据库、添加超级管理员帐号、更换面板端口等操作。**使用一键脚本安装后，如果仍需使用一脚脚本更新，请勿更改数据库用户名和密码，否则会使得更新后无法同步更改后的数据库用户名和密码，导致数据库连接出错。**

```shell
bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
# 国内机器安装可以选择使用 fastgit 镜像
# bash <(curl -fsSL https://raw.fastgit.org/Aurora-Admin-Panel/deploy/main/install.sh) --mirror
```

一键脚本默认从 Github 拉取所需的配置文件，如果是在国内机器安装，请检查连接 Github 的网络是否正常。一键脚本也支持更新测试版本，只需要添加 `--dev` 参数执行脚本即可，但是测试版本并不稳定，可能会出现各种问题，不建议在生产环境中使用。

## 手动安装 — 中转被控机

**对于不在中转机器（被控机）支持进度里面的系统版本，无法直接使用面板连接中转机器。** 如果被控机支持运行 docker，则可以利用被控机运行一个网络模式为 host 的特权 centos7 容器，并利用面板连接到 centos7 docker 中，实现转发功能的操作。（或可以参考 [aurora-client](https://github.com/smartcatboy/aurora-client) 直接编译被控端镜像运行）

```shell
# 启动 centos 7 特权容器，设置网络模式为 host ，并设置为开机自启动
sudo docker run -d --privileged --name aurora-client --network=host --restart=always -v /lib/modules:/lib/modules centos:7 /usr/sbin/init
# 进入 centos 7 容器内
sudo docker exec -it aurora-client bash
# 在 docker 内安装 openssh 服务端，并修改容器的 ssh 端口（避免跟主机 ssh 服务冲突）
yum makecache -y && yum install -y openssh-server
sed -i "s/#Port 22/Port 62222/" /etc/ssh/sshd_config
# 启用 ssh 服务
systemctl enable --now sshd
# 安装 iptables 转发必须的依赖
yum install -y iproute
# 为 root 账号设置密码
passwd
# 直接在面板添加中转机器 ip:62222 ，用户名 root ，密码为刚刚设置的密码
# 卸载时候只需要在面板删除对应中转机，并删除 aurora-client 容器即可
sudo docker stop aurora-client && sudo docker rm aurora-client
```

## 手动安装 — 面板主控机

如果一键脚本提示不支持当前系统版本时，可以尝试使用手动安装的方式。

### 1. 安装 docker（必须）

```shell
curl -fsSL https://get.docker.com | sudo bash -s docker && sudo systemctl enable --now docker
# 国内机器安装可以选择使用阿里镜像
# curl -fsSL https://get.docker.com | sudo bash -s docker --mirror Aliyun && sudo systemctl enable --now docker

# 如果当前执行安装命令的不是 root 用户，请执行下面部分
# =================非root用户执行==================
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
# =================非root用户执行==================
```

### 2. 安装 docker-compose（必须）

```shell
sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose

# 如果 /usr/local/bin 不在环境变量 PATH 里
# ============================可选================================
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
# ============================可选================================
```

### 3. 生成 SSH 密钥（建议，非必须）

此步操作目的为让面板服务器通过密钥连接被控机 ssh ，**可以提高被控机安全性，非必须步骤**，如果不采用密钥连接方式，后续在面板添加被控机使可以选择使用密码连接的方式。

```shell
# 如果面板服务器并没有已经生成好的 ssh 密钥
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# 后面一直回车，跳过设置 passphase 即可
# 然后还需要将面板服务器 ~/.ssh/id_rsa.pub 里面的内容复制到每一台被控机的 ~/.ssh/authorized_keys 文件中去。
```

### 4. 安装并启动面板（必须）

```shell
mkdir -p ~/aurora && cd ~/aurora && wget https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose.yml -O docker-compose.yml && docker-compose up -d
# 创建管理员用户（密码必须设置8位以上，否则无法登陆）
docker-compose exec backend python app/initial_data.py
```
之后可以访问 `http://你的IP:8000` 进入面板。

## 配置说明

1. 修改所有的 `POSTGRES_USER` 和 `POSTGRES_PASSWORD` ，以及相应的 `DATABASE_URL` ，虽然数据库不公开，但使用默认的数据库用户和密码并不安全！

2. 后端默认会发送错误信息到 Sentry （**建议使用测试版本不要关闭，方便排查错误**），可能会导致信息泄漏，移除 `ENABLE_SENTRY: 'yes'` 就好。

3. 默认挂载 `~/.ssh/id_rsa` 作为连接服务器的密钥，如使用其他密钥或者不使用密钥可以删除配置文件中的 `- $HOME/.ssh/id_rsa:/app/ansible/env/ssh_key` 。

## 更新

### 正式版
```shell
cd ~/aurora
wget https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose.yml -O docker-compose.yml
docker-compose pull && docker-compose down --remove-orphans && docker-compose up -d
```

### ~~内测版（目前已不维护，请不要使用）~~
```shell
cd ~/aurora
wget https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose-dev.yml -O docker-compose.yml
docker-compose pull && docker-compose down --remove-orphans && docker-compose up -d
```

## 数据库备份与恢复

### 备份
```shell
docker-compose exec -T postgres pg_dump -d aurora -U [数据库用户名，默认aurora] -c > data.sql
```

### 恢复
```shell
# 首先先把所有服务停下
docker-compose down
# 只启动数据库服务
docker-compose up -d postgres
# 执行数据恢复
docker-compose exec -T postgres psql -d aurora -U [数据库用户名，默认aurora] < data.sql
# 然后正常启动所有服务
docker-compose up -d
```

## 卸载面板
```shell
docker-compose down
docker volume rm aurora_db-data
docker volume rm aurora_app-data
```

## 面板长什么样？

### 服务器管理页面

![](https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/img/servers.png)

#### 修改/添加服务器

![](https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/img/servers_edit.png)

### 服务器端口管理页面

![](https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/img/server.png)

#### 添加/编辑端口

![](https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/img/server_port_edit.png)

#### 端口分配页面

![](https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/img/server_port_users.png)

#### 端口设置 iptables

![](https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/img/server_port_edit_rule_iptables.png)

#### 端口设置 gost

![](https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/img/server_port_edit_rule_gost.png)
