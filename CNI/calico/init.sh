#!/usr/bin/env bash

#wget https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/rbac.yaml
#wget https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/calico.yaml
# rbac
#kubectl create -f  https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
#
## 部署
#kubectl create -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

etcdIPPorts=$(awk -v PROT="${ETCD_PROTOCOL}"  '{if($1 == "[k8s-node]"){exit}else{print PROT"://"$1":2379"}}' ../../node.hosts   |tail -n +2  | tr '\n' ','| sed -e 's/,$//' )

#kubectl create -n kube-system secret generic calico-etcd-secrets \
#--from-file=etcd-key=/etc/etcd/ssl/etcd-key.pem \
#--from-file=etcd-cert=/etc/etcd/ssl/etcd.pem \
#--from-file=etcd-ca=/etc/etcd/ssl/ca.pem

sed  "s@.*etcd_endpoints:.*@  etcd_endpoints: ${etcdIPPorts}@gi" calico.yaml > calico.tmp.yaml

export ETCD_CERT=`cat /etc/etcd/ssl/etcd.pem | base64 | tr -d '\n'`
export ETCD_KEY=`cat /etc/etcd/ssl/etcd-key.pem | base64 | tr -d '\n'`
export ETCD_CA=`cat /etc/etcd/ssl/ca.pem | base64 | tr -d '\n'`
sed -i "s@.*etcd-cert:.*@\ \ etcd-cert:\ ${ETCD_CERT}@gi" calico.tmp.yaml
sed -i "s@.*etcd-key:.*@\ \ etcd-key:\ ${ETCD_KEY}@gi" calico.tmp.yaml
sed -i "s@.*etcd-ca:.*@\ \ etcd-ca:\ ${ETCD_CA}@gi" calico.tmp.yaml

kubectl --namespace kube-system apply -f  rbac.yaml -f calico.tmp.yaml

#cd /usr/local/bin
#wget https://github.com/projectcalico/calicoctl/releases/download/v2.0.0/calicoctl
chmod 755 calicoctl-linux-amd64
mkdir /etc/calico
##验证
cat > /etc/calico/calicoctl.cfg<<EOF
apiVersion: v1
kind: calicoApiConfig
metadata:
spec:
    datastoreType: "etcdv2"
    etcdEndpoints: "${etcdIPPorts}"
    etcdKeyFile: "/etc/etcd/ssl/etcd-key.pem"
    etcdCertFile: "/etc/etcd/ssl/etcd.pem"
    etcdCACertFile: "/etc/etcd/ssl/ca.pem"
EOF

calicoctl-linux-amd64 node status
