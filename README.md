# 极光面板

## 这是什么？

这是一个多服务器端口租用管理面板，你可以添加多台服务器及端口，并将其分配给任意注册用户，租户则可以很方便地使用被分配的端口来完成各种操作，目前支持的端口功能：

- iptables
- [socat](http://www.dest-unreach.org/socat/)
- [gost](https://github.com/ginuerzh/gost)
- [ehco](https://github.com/Ehco1996/ehco)
- [v2ray](https://github.com/v2ray/v2ray-core)
- [brook](https://github.com/txthinking/brook)
- [iperf](https://iperf.fr)
- [wstunnel](https://github.com/erebe/wstunnel)
- [shadowsocks](https://github.com/shadowsocks)
- [tinyPortMapper](https://github.com/wangyu-/tinyPortMapper)
- [Prometheus Node Exporter](https://github.com/leishi1313/node_exporter)

### 限制

本面板无需单独配置被控机，只需保证安装面板的服务器能够通过 ssh 连接至被控机即可，**但被控机需确保已安装 systemd 和 python** ，且 iptables 功能（包括流量控制等依赖 iptables 的功能）需要被控端安装了 iptables ，gost 只支持 Linux X64 系统。

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
- [x] ARM64 （仅支持部分功能，如 iptables ）

## 怎么跑起来？&nbsp;👉<a href="#%E6%9B%B4%E6%96%B0">更新</a>

### 安装 docker（必须）

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

### 安装 docker-compose（必须）

```shell
sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 如果 /usr/local/bin 不在环境变量 PATH 里
# ============================可选================================
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
# ============================可选================================
```

### 生成 SSH 密钥（建议，非必须）

此步操作目的为让面板服务器通过密钥连接被控机 ssh ，可以提高被控机安全性，非必须步骤，如果不采用密钥连接方式，后续在面板添加被控机使可以选择使用密码连接的方式。

```shell
# 如果面板服务器并没有已经生成好的 ssh 密钥
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# 后面一直回车，跳过设置 passphase 即可
# 然后还需要将面板服务器 ~/.ssh/id_rsa.pub 里面的内容复制到每一台被控机的 `~/.ssh/authorized_keys` 文件中去。
```

### 安装 / 启动面板（必须）

```shell
mkdir -p ~/aurora
cd ~/aurora
wget https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose.yml -O docker-compose.yml
# 测试版采用以下链接的配置文件，正式版跳过
# wget https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose-dev.yml -O docker-compose.yml
docker-compose up -d
# 创建管理员用户（密码必须设置8位以上，否则无法登陆）
docker-compose exec backend python app/initial_data.py
```
之后可以访问 `http://你的IP:8000` 进入面板。

## 配置说明

- 修改所有的 `POSTGRES_USER` 和 `POSTGRES_PASSWORD` ，以及相应的 `DATABASE_URL` ，虽然数据库不公开，但使用默认的数据库用户和密码并不安全！
- 后端默认会发送错误信息到 Sentry，可能会导致信息泄漏，移除 `ENABLE_SENTRY: 'yes'` 就好。
- 默认挂载 `~/.ssh/id_rsa` 作为连接服务器的密钥，如使用其他密钥或者不使用密钥可以删除配置文件中的 `- $HOME/.ssh/id_rsa:/app/ansible/env/ssh_key` 。

## 面板更新

### 正式版
```shell
cd aurora
wget https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/docker-compose.yml -O docker-compose.yml
docker-compose pull && docker-compose down --remove-orphans && docker-compose up -d
```

### 测试版
```shell
cd aurora
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
docker-compose up postgres
# 在另外一个窗口，执行数据恢复
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
