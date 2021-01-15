# 基于TLS-etcd集群的高可用高性能(calico)k8s集群自动化离线安装部署包


## 下载脚本
```
cd /data1/ms

首次安装
git clone 'https://cmsdev:!!Yhb6sqt!!@git.staff.sina.com.cn/cms/backend/k8s.git' 
#repo已存在
sed -i 's|https://git.staff.sina.com.cn|https://cmsdev:!!Yhb6sqt!!@git.staff.sina.com.cn|g' .git/config \
&& git reset --hard \
&& git pull origin master 

```

## 安装免密码登录和ansible
```bash
(cd centos_init; sh -x init.sh ssh;sh -x init.sh master; )
```

## 修改配置
```bash
#修改node.hosts文件
#init_k8s.sh中的变量

export MASTER_VIP="10.79.217.185"
#第1个master的IP
localIP='172.16.114.56'
otherMasterIPs={172.16.114.58,10.79.40.174}

```


## 初始化master nodes
```
sudo sh -x  init_k8s.sh master reset;
sudo sh -x  init_k8s.sh master 
```

## 初始化worker nodes
```
sudo sh -x  init_k8s.sh node reset;
sudo sh -x  init_k8s.sh node 
```

## 检查etcd集群
```bash
#健康
etcdctl \
  --endpoints=https://127.0.0.1:2379  \
  --ca-file=/etc/etcd/ssl/ca.pem \
  --cert-file=/etc/etcd/ssl/etcd.pem \
  --key-file=/etc/etcd/ssl/etcd-key.pem \
  cluster-health

#选举
etcdctl \
  --endpoints=https://127.0.0.1:2379  \
  --ca-file=/etc/etcd/ssl/ca.pem \
  --cert-file=/etc/etcd/ssl/etcd.pem \
  --key-file=/etc/etcd/ssl/etcd-key.pem \
  member list
```


## 检查nodes
```bash
kubectl get nodes --all-namespaces -o wide
```
```text
NAME                                        STATUS    ROLES     AGE       VERSION   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                    CONTAINER-RUNTIME
k8s-145.cms.msina.tc.sinanode.com           Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-148.cms.msina.tc.sinanode.com           Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-174.cms.msina.yf.sinanode.com           Ready     master    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-200.cms.msina.dbl.sinanode.com          Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-693.2.2.el7.toa.2.x86_64   docker://17.3.3
k8s-56.cms.msina.yf.sinanode.com            Ready     master    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-58.cms.msina.yf.sinanode.com            Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
microservice138.cms.msina.yz.sinanode.com   Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
```

## 检查pods
```bash
#多master表示master高可用
kubectl get nodes -n kube-system -o wide
```
```text
NAME                                        STATUS    ROLES     AGE       VERSION   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                    CONTAINER-RUNTIME
k8s-145.cms.msina.tc.sinanode.com           Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-148.cms.msina.tc.sinanode.com           Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-174.cms.msina.yf.sinanode.com           Ready     master    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-200.cms.msina.dbl.sinanode.com          Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-693.2.2.el7.toa.2.x86_64   docker://17.3.3
k8s-56.cms.msina.yf.sinanode.com            Ready     master    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
k8s-58.cms.msina.yf.sinanode.com            Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
microservice138.cms.msina.yz.sinanode.com   Ready     <none>    1d        v1.9.1    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.2.el7.toa.2.x86_64   docker://17.3.3
```


```bash
#Calico status
./CNI/calico/calicoctl-linux-amd64 node status
```
```text
Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+------------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |   SINCE    |    INFO     |
+---------------+-------------------+-------+------------+-------------+
| 10.79.40.174  | node-to-node mesh | up    | 2019-07-30 | Established |
| 172.16.114.58 | node-to-node mesh | up    | 2019-07-30 | Established |
| 10.73.14.145  | node-to-node mesh | up    | 2019-07-30 | Established |
| 10.41.14.200  | node-to-node mesh | up    | 2019-07-30 | Established |
| 10.73.14.148  | node-to-node mesh | up    | 2019-07-30 | Established |
| 10.39.40.138  | node-to-node mesh | up    | 2019-07-30 | Established |
+---------------+-------------------+-------+------------+-------------+

IPv6 BGP status
No IPv6 peers found.

```



## dump image to file
```bash

#docker save $(docker images | sed '1d' | awk '{print $1 ":" $2 }') -o allinone.tar

#docker load -i allinone.tar

```







