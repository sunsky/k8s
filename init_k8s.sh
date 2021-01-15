#!/usr/bin/env bash


export MASTER_VIP="10.79.217.185"
#第1个master的IP
localIP='172.16.114.56'
otherMasterIPs={172.16.114.58,10.79.40.174}

ansible all -m shell  -a 'grep -r release /etc/*release'

if [[ "$1" == "master" ]]; then
    ansible-playbook -i ./node.hosts  ./master.ansible.yml  --tags "git-update"

    if [[ "$2" == "reset" ]]; then
        ansible-playbook -i ./node.hosts ./master.ansible.yml  --tags "kube_reset"
    else
        ansible-playbook -i ./node.hosts ./master.ansible.yml  --tags "kube_reset_light"
    fi
    ansible-playbook  -i ./node.hosts ./master.ansible.yml  --tags "install_kubelet"


    sh -x k8s.sh --master-address ${localIP} --node-type master
    for ip in ${otherMasterIPs};do
        echo "syncing conf to ${ip}"
        scp -P222 -r /etc/kubernetes/pki root@${ip}:/etc/kubernetes/
        scp -P222 -r /etc/kubernetes/kubeadm.conf root@${ip}:/etc/kubernetes/config.yaml
        #quickly be master:
        #kubeadm init --config /etc/kubernetes/kubeadm.conf  --ignore-preflight-errors=all
    done
    ansible-playbook  -i ./node.hosts ./master.ansible.yml  --tags "install-master"
    echo "master-cluster creating finished."

    sed -i 's%export KUBECONFIG=/etc/kubernetes/admin.conf;%%ig' ~/.bashrc ; echo "export KUBECONFIG=/etc/kubernetes/admin.conf;">> ~/.bashrc
    export KUBECONFIG=/etc/kubernetes/admin.conf;
    source ~/.bashrc

    ansible-playbook  -i ./node.hosts ./master.ansible.yml  --tags "install_base_plugins"


elif [[ "$1" == "etcd" ]]; then
    (cd etcd_ca; sh init.sh)
    ansible-playbook -i ./node.hosts ./master.ansible.yml  --tags "etcd_install"
else
    ansible-playbook -i ./node.hosts ./node.ansible.yml  --tags "git-update"
    if [[ "$2" == "reset" ]]; then
        ansible-playbook -i ./node.hosts ./node.ansible.yml  --tags "kube_reset"
    else
        ansible-playbook -i ./node.hosts ./node.ansible.yml  --tags "kube_reset_light"
    fi
    ansible-playbook -i ./node.hosts ./node.ansible.yml  --tags "install_kubelet"

    CA_SHA=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
    #quickly be worker node:
    #$(kubeadm token create --print-join-command)

    export KUBE_TOKEN="863f67.19babbff7bfe8543"
    for ip in $(awk  '{if($1 == "[k8s-node]"){isNode=1}else if(isNode==1){print $1}}' node.hosts ); do
        workerCmd="kubeadm join --token ${KUBE_TOKEN} --discovery-token-ca-cert-hash sha256:${CA_SHA} ${MASTER_VIP}:6443 --ignore-preflight-errors=all;"
        echo $workerCmd
        ssh -p222 root@${ip}  $workerCmd
    done
    echo "worker-nodes creating finished."
fi


