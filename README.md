# For [Housesigma Interview](https://github.com/housesigma/hr-interview)

## 一、写一个定时执行的Bash脚本，每月的一号凌晨1点 对 MongoDB 中 test.user_logs 表进行备份、清理

> 问题描述
> - 首先备份上个月的数据，备份完成后打包成.gz文件
> - 备份文件通过sfpt传输到 Backup [bak@bak.ipo.com] 服务器上，账户已经配置在~/.ssh/config;\
> - 备份完成后，再对备份过的数据进行清理: create_on [2024-01-01 03:33:11] ;\
> - 如果脚本执行失败或者异常，则调用 [https://monitor.ipo.com/webhook/mongodb ];\
> - 这个表每日数据量大约在 200w 条, 单条数据未压缩的存储大小约 200B;

1. 编写脚本内容 [backup.sh](https://github.com/liyujun-dev/housesigma-interview/tree/main/Q1/backup.sh)，并设置可执行权限

```bash
chmod +x backup.sh
mv backup.sh /usr/local/bin/backup.sh
```

2. 执行 `crontab -e`，并写入定时任务

```crontab
0 1 1 * * /usr/local/bin/backup.sh
```

## 二、根据要求提供一份Nginx配置：

> 问题描述
> - 域名：ipo.com, 支持https、HTTP/2
> - 非http请求经过301重定向到https
> - 根据UA进行判断，如果包含关键字 **"Google Bot"**, 反向代理到 server_bot[bot.ipo.com] 去处理
> - /api/{name} 路径的请求通过**unix sock**发送到本地 **php-fpm**，文件映射 **/www/api/{name}.php** 
> - /api/{name} 路径下需要增加限流设置，只允许每秒1.5个请求，超过限制的请求返回 **http code 429**
> - /static/ 目录下是纯静态文件
> - 其它请求指向目录 **/www/ipo/**, 查找顺序 index.html --> public/index.html --> /api/request

Nginx 配置见 [nginx.conf](https://github.com/liyujun-dev/housesigma-interview/tree/main/Q2/nginx.conf)

## 三、在生产环境中，应用程序是通过Haproxy来读取Slave集群，但是偶尔会产生 **SQLSTATE[HY000]: General error: 2006 MySQL server has gone away** 的错误，请根据经验，给出一排查方案与可能的方向，与开发一起定位问题, 现已经排查：

> 问题描述
> - 故障发生时，服务器之间防火墙正常，服务器之间可以正常通信;
> - 故障SQL均可以正常查询，同时不存在性能问题;
> - 故障频率没有发现特别规律，与服务器负载没有正相关;
> - 查看各服务的日志，只发现了错误信息，但没有进一步的说明;

解决思路：

1. MySQL 配置检查
  
  - `wait_timeout` 和 `interactive_time`

    连接在闲置指定时间后会被关闭，如果应用程序此时没有发送任何请求，就会导致连接丢失

    ```sql
    SHOW VARIABLE LIKE 'wait_timeout';
    SHOW VARIABLE LIKE 'interactive_timeout';
    ```
  
  - `max_allowed_packet`

    如果执行的 SQL 涉及大数据量，超过 `max_allowed_packet` 设定值，也会导致连接丢失

    ```sql
    SHOW VARIABLE LIKE 'max_allowed_packet';
    ```

2. HAProxy 配置检查

- 连接超时设置，确保不会过早关闭空闲连接

```haproxy
timeout client 30s
timeout server 30s
timeout connect 3s
```

- 使用合理的负载均衡配置，避免将过多的请求发送到某一台 Slave

3. 网络稳定性

- 使用 `ping`、`tcpdump`、`traceroute` 等工具监控网络延迟和丢包情况

4. MySQL 日志分析

- 开启慢日志查询，分析是否有慢查询导致连接超时或资源竞争

5. 监控与指标

- 使用监控工具 `Prometheus` 或 `Grafana` 监控数据库性能指标，包括连接数、查询响应时间、慢查询等


## 四、有一个简单的三层 Web 应用，包含前端（frontend）、中间层（backend），和数据库（database）三部分。这些应用都已经打包成 Docker 镜像，现在需要部署在 Kubernetes 中。

> 该集群是一个全新部署的集群，除了 kube-proxy, CoreDNS, CNI (Calico) 外没有部署任何应用。请根据下面的要求分别提供部署所需的所有 yaml 定义及部署说明，可以使用 helm 等工具。\
> 具体要求如下：

> 1. 前端服务（frontend）：
>  - 需要通过外部域名：frontend.example.com访问并支持 https，可以self-signed
>  - 支持自动扩缩容，根据 CPU (80%) 使用率在 2 到 10 个 Pod 之间调整实例数量
>  - 该 Pod 需要配置 health check, HTTP 协议 9090 端口
>
> 2. 中间层服务（backend）：
> - 仅供前端服务调用，不能对外部暴露
> - 支持通过环境变量来配置对 database 的访问，ENV KEY: DB_HOST/DB_NAME/DB_USER/DB_PASS...
> - 为了保证高可用性，至少要有 3个Pod 同时存活，同时需要 **尽可能** 避免多个 Pod 运行在同一个 Node 上
>
> 3. 数据库服务（database）：
> - 数据库只允许中间层服务访问，不能通过 ClusterIP 之外的方式暴露
> - 需要考虑持久化问题，数据存储在 /var/lib/mysql 目录下, 确保 Pod 崩溃或重建后数据不丢失

使用 `Helm` 技术创建了 Kubernetes 应用部署模板，见 [Q4 目录](https://github.com/liyujun-dev/housesigma-interview/tree/main/Q4/)

```text
 Q4
├──  .helmignore
├──  Chart.yaml
├──  templates
│  ├──  deployment-backend.yaml
│  ├──  deployment-frontend.yaml
│  ├──  deployment-mysql.yaml
│  ├──  hpa.yaml
│  ├──  ingress.yaml
│  ├──  pvc.yaml
│  ├──  secret-tls.yaml
│  ├──  service-backend.yaml
│  ├──  service-frontend.yaml
│  └──  service-mysql.yaml
└──  values.yaml
```

另外还需要在集群上安装任一 `Ingress Controller`，如 `ingress-nginx` 或 `traefik`

```bash
# 参考: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade \
  --install \
  --namespace ingress-nginx \
  --create-namespace \
  --version 4.11.2 \
  ingress-nginx ingress-nginx/ingress-nginx
```
