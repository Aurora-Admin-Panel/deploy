# 极光面板

## 这是什么？

这是一个多服务器端口租用管理面板，你可以添加多台服务器及端口，并将其分配给任意注册用户，租户则可以很方便地使用被分配的端口来完成各种操作，目前支持的端口功能：

- iptables
- [socat](http://www.dest-unreach.org/socat/)
- [gost](https://github.com/ginuerzh/gost)
- [ehco](https://github.com/Ehco1996/ehco)
- [brook](https://github.com/txthinking/brook)
- [wstunnel](https://github.com/erebe/wstunnel)
- [tinyPortMapper](https://github.com/wangyu-/tinyPortMapper)
- [Prometheus Node Exporter](https://github.com/leishi1313/node_exporter)

### 限制

本面板无需被控，只需要安装面板的服务器能够通过 ssh 连接被控机即可，但是被控机需使用 systemd，且 iptables 功能只支持安装了 iptables 的服务器，gost 只支持 linux x86 系统。
暂时只在 CentOS 7+，Debian 9+，Ubuntu 18+上测试通过。

## 怎么跑起来？&nbsp;👉<a href="#%E6%9B%B4%E6%96%B0">更新</a>

### 安装 docker

```shell
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

#### 非 root 用户

```
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

### 安装 docker-compose

```shell
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
# 如果/usr/local/bin不在PATH里
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### 生成 SSH 密钥

如果面板机上没有 ssh key 的话

```shell
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# 跳过设置passphase即可
```

然后还需要将`~/.ssh/id_rsa.pub`里面的内容复制到被控机的`~/.ssh/authorized_keys`

### 安装/启动面板

```shell
git clone https://github.com/Aurora-Admin-Panel/deploy.git
cd deploy
docker-compose up -d
# 更新数据库
docker-compose run --rm backend alembic upgrade heads
# 创建超级用户
docker-compose run --rm backend python app/initial_data.py
```

#### 设置机器自动重启面板

```shell
sudo systemctl enable docker
```

## 配置

- 修改所有的`POSTGRES_USER`和`POSTGRES_PASSWORD`，以及相应的`DATABASE_URL`，虽然数据库不公开，但使用默认的数据库用户和密码并不安全！
- 后端默认会发送错误信息到 Sentry，可能会导致信息泄漏，移除`ENABLE_SENTRY: 'yes'`就好
- 默认挂载`~/.ssh/id_rsa`作为连接服务器的密钥，如使用其他密钥或者不使用密钥可以删除`- $HOME/.ssh/id_rsa:/app/ansible/env/ssh_key`

## 更新

### 正式版
```shell
git reset --hard HEAD
git pull origin main
docker-compose pull && docker-compose down && docker-compose up -d && docker-compose exec backend alembic upgrade heads
```

### 测试版
```shell
git reset --hard HEAD
git pull origin main
docker-compose -f docker-compose-dev.yml pull && docker-compose -f docker-compose-dev.yml down && docker-compose -f docker-compose-dev.yml up -d && docker-compose -f docker-compose-dev.yml exec backend alembic upgrade heads
```

## 数据库备份与恢复

### 备份
```shell
docker-compose exec postgres pg_dump -d aurora -U [数据库用户名，默认aurora] -a > data.sql
```

### 恢复
```shell
docker-compose exec -T postgres psql -d aurora -U [数据库用户名，默认aurora] < data.sql
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
