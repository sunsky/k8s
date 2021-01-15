#!/usr/bin/env bash
sudo su
export PASSWORD=scpcomos${RANDOM}

case $1 in
    "m" | "master" )
        sudo useradd -U kube
        sudo yum install epel-release ansible sshpass -y
        for i in $(awk  '{if($1 != "[k8s-node]" && $1!="[k8s-master]" ){print $1}}' ../node.hosts  );do  sshpass  -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no  -i /root/.ssh/id_rsa.pub root@"$i" -p 222 ; echo $? ; done

        #check : ssh root@10.39.40.138 -p 222
        cp -f /data1/ms/k8s/centos_init/ansible/ansible.cfg /etc/ansible/
        cp -f /data1/ms/k8s/node.hosts /etc/ansible/
        ;;
    "n" | "node" )

        ;;
    "ssh" )
        rm -rf ~/.ssh/id_rsa*
        rm -rf ~/.ssh/known_hosts
        rm -rf /etc/ssh/ssh_host_*_key*
        mkdir -p ~/.ssh
        cp -f /data1/ms/k8s/centos_init/sshd_config2 /etc/ssh/sshd_config2
        cp -f /data1/ms/k8s/centos_init/ssh_config /etc/ssh/ssh_config
        cd ~/.ssh && rm -rf ~/.ssh/ssh_host_rsa_key ssh_host_ecdsa_key ssh_host_ed25519_key ssh_host_dsa_key
        ps aux|grep sshd_config2|grep -v grep| awk '{print $2}'|xargs sudo kill
        cd /etc/ssh/   && ssh-keygen -N '' -f $HOME/.ssh/id_rsa && ssh-keygen -N '' -f ./ssh_host_rsa_key  \
        && ssh-keygen -t ecdsa -N '' -f  ./ssh_host_ecdsa_key  && ssh-keygen -t ed25519 -N '' -f  ./ssh_host_ed25519_key  && ssh-keygen -t dsa  -N '' -f  ./ssh_host_dsa_key && /sbin/sshd -f /etc/ssh/sshd_config2
        #开机启动
        echo "/sbin/sshd -f /etc/ssh/sshd_config2" >> /etc/rc.d/rc.local
        echo "$PASSWORD" | passwd root --stdin

        ;;
    *)
        kube_help
        ;;
 esac


