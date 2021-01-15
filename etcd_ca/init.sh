#!/usr/bin/env bash

set -e


ln -sf /data1/ms/k8s/etcd_ca/cfssl* /usr/bin/
#创建 CA 配置文件
cat > ca-config.json <<EOF
{
"signing": {
"default": {
  "expiry": "8760h"
},
"profiles": {
  "kubernetes": {
    "usages": [
        "signing",
        "key encipherment",
        "server auth",
        "client auth"
    ],
    "expiry": "8760h"
  }
}
}
}
EOF
#CSR是Certificate Signing Request的英文缩写，即证书请求文件，也就是证书申请者在申请数字证书时由CSP(加密服务提供者)在生成私钥的同时也生成证书请求文件，证书申请者只要把CSR文件提交给证书颁发机构后，证书颁发机构使用其根证书私钥签名就生成了证书公钥文件，也就是颁发给用户的证书。
cat >  ca-csr.json <<EOF
{
"CN": "kubernetes",
"key": {
"algo": "rsa",
"size": 2048
},
"names": [
{
  "C": "CN",
  "ST": "BeiJing",
  "L": "BeiJing",
  "O": "k8s",
  "OU": "System"
}
]
}
EOF
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
ls ca*

#创建 etcd 证书签名请求
#hosts 字段指定授权使用该证书的 etcd 节点 IP；
#每个节点IP 都要在里面 或者 每个机器申请一个对应IP的证书
allowedIPs=$(awk '{if($1!="[k8s-node]" && $1!="[k8s-master]")print "\""$1"\","}'  ../node.hosts)
cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
${allowedIPs}
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

#生成 etcd 证书和私钥
cfssl gencert -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

ls etcd*

#rm -rf /etc/etcd/ssl
#mkdir -p /etc/etcd/ssl
#cp etcd.pem etcd-key.pem ca.pem /etc/etcd/ssl/
#同步到其他node
#将生成好的etcd.pem和etcd-key.pem以及ca.pem三个文件拷贝到目标主机的/etc/etcd/ssl目录下
master_ips=$(awk '{if($1 == "[k8s-node]"){exit}else{print $1}}' ../node.hosts |tail -n +2)
for IP in ${master_ips}; do
    scp -o StrictHostKeyChecking=no -P 222 -r etcd.pem etcd-key.pem ca.pem  root@${IP}:/etc/etcd/ssl/
    echo "${IP} syncing ca ok "
        #验证
    ssh -p222 root@${IP} etcdctl \
  --endpoints=https://${IP}:2379  \
  --ca-file=/etc/etcd/ssl/ca.pem \
  --cert-file=/etc/etcd/ssl/etcd.pem \
  --key-file=/etc/etcd/ssl/etcd-key.pem \
  cluster-health
done

