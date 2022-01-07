# 极光面板

## 这是什么？

这是一个多服务器端口租用管理面板，你可以添加多台服务器及端口，并将其分配给任意注册用户，租户则可以很方便地使用被分配的端口来完成各种操作，目前支持的端口功能：

- [iptables](https://www.netfilter.org/) ( AMD64 / ARM64 )
- [socat](http://www.dest-unreach.org/socat/) ( AMD64 / ARM64 )
- [gost](https://github.com/ginuerzh/gost) ( AMD64 / ARM64 )
- [ehco](https://github.com/Ehco1996/ehco) ( AMD64 / ARM64 )
- [v2ray](https://github.com/v2ray/v2ray-core) ( AMD64 )
- [brook](https://github.com/txthinking/brook) ( AMD64 / ARM64 )
- [iperf](https://iperf.fr) ( AMD64 / ARM64 )
- [wstunnel](https://github.com/erebe/wstunnel) ( AMD64 )
- [shadowsocks](https://github.com/shadowsocks) ( AMD64 / ARM64 (only AEAD) )
- [tinyPortMapper](https://github.com/wangyu-/tinyPortMapper) ( AMD64 / ARM64 )
- [Prometheus Node Exporter](https://github.com/leishi1313/node_exporter) ( AMD64 )

### 面板服务器与被控机说明

**面板建议安装在单独的一台服务器上，建议安装配置为不低于单核 1G 内存的 VPS 中**，可以直接部署到本地。**被控机端无需做任何特别配置，只需保证面板服务器能够通过 ssh 连接至被控机即可。**

面板服务器在连接被控机的时候会检测被控机是否已经安装好 python （python 为被控机必须依赖），如果被控机上没安装会自动在被控机上通过 apt / yum 执行 python 安装（优先安装python3），如果被控机没有自带 python 且自动安装失败会导致面板显示被控机连接失败（表现为被控机连接状态持续转圈）。从 0.16.5 版本开始，会加入对被控机 iptables 和 systemd 依赖的检测安装，以保证转发、流量统计等必需功能正常运行。

#### 面板（主控机）支持进度：

- 操作系统
- [x] CentOS 7+
- [x] Debian 8+
- [x] Ubuntu 18+
- 虚拟平台
- [x] KVM
- [x] VMware
- [ ] OVZ （理论支持，未测试）
- CPU 架构
- [x] AMD64
- [x] ARM64 （0.15.3+ 镜像版本支持）

#### 中转机器（被控机）支持进度：

- 操作系统
- [x] CentOS 7+
- [x] Debian 8+
- [x] Ubuntu 18+
- 虚拟平台
- [x] KVM
- [x] VMware
- [x] OVZ
- CPU 架构
- [x] AMD64
- [x] ARM64 （0.16.3+ 镜像版本支持，仅支持部分功能）

## 怎么跑起来？&nbsp;👉<a href="#%E6%9B%B4%E6%96%B0">更新</a>

### 1. 安装 docker（必须）

```shell
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
# 启动并设置开机自启docker
systemctl enable --now docker

# 如果当前执行安装命令的不是 root 用户，请执行下面部分
# =================非root用户执行==================
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
# =================非root用户执行==================
```

### 2. 安装 docker-compose（必须）

```shell
sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

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

### 4. 安装 / 启动面板（必须）

```shell
mkdir -p ~/aurora
cd ~/aurora
wget https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose.yml -O docker-compose.yml
docker-compose up -d
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
docker-compose exec postgres pg_dump -d aurora -U [数据库用户名，默认aurora] -c > data.sql
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
