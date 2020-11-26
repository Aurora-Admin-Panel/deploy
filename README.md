# 极光面板

## How to run
```shell
docker-compose up -d
# 更新数据库
docker-compose run --rm backend alembic upgrade heads
# 创建超级用户
docker-compose run --rm backend python app/initial_data.py
```

## 配置
- 修改所有的`POSTGRES_USER`和`POSTGRES_PASSWORD`，以及相应的`DATABASE_URL`，虽然数据库不公开，但使用默认的数据库用户和密码并不安全！
- 后端默认会发送错误信息到Sentry，可能会导致信息泄漏，移除`ENABLE_SENTRY: 'yes'`就好
- 默认挂载`~/.ssh/id_rsa`作为连接服务器的密钥，如使用其他密钥或者不使用密钥可以删除`- $HOME/.ssh/id_rsa:/app/ansible/env/ssh_key`