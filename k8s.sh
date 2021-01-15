#!/usr/bin/env bash
set -x
#如果任何语句的执行结果不是true则应该退出,set -o errexit和set -e作用相同
set -e
#turn off history substitution
set +H

#id -u显示用户ID,root用户的ID为0
root=$(id -u)
#脚本需要使用root用户执行
if [ "$root" -ne 0 ] ;then
    echo "must run as root"
    exit 1
fi
#docker存储目录
if [ ! -n "$DOCKER_GRAPH" ]; then
    export DOCKER_GRAPH="/data1/docker"
fi
if [ ! -n "$KUBE_TOKEN" ]; then
	export KUBE_TOKEN="863f67.19babbff7bfe8543"
fi
export ETCD_PROTOCOL="https"
export MASTER_VIP="10.79.217.185"



install_rpm(){
   for i in $1
   do
	   if  test -z `rpm -qa $i`
	   then
		   echo "$i isn't install"
		   rpm -ivh "$i*.rpm" ||true
	   else
		   echo "$i was installed"
	   fi
   done
}


linux_os()
{
    cnt=$(cat /etc/centos-release|grep "CentOS"|grep "release 7"|wc -l)
    if [ "$cnt" != "1" ];then
       echo "Only support CentOS 7...  exit"
       exit 1
    fi
    install_rpm "epel-release ntpdate" || true
    echo '*/30 * * * * /usr/sbin/ntpdate time7.aliyun.com >/dev/null 2>&1' > /tmp/crontab2.tmp
    crontab /tmp/crontab2.tmp || true
    systemctl start ntpdate.service || true
    echo "linux_os initialling is done"

#    echo "* soft nofile 65536" >> /etc/security/limits.conf
#    echo "* hard nofile 65536" >> /etc/security/limits.conf
#    echo "* soft nproc 65536"  >> /etc/security/limits.conf
#    echo "* hard nproc 65536"  >> /etc/security/limits.conf
#    echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
#    echo "* hard memlock  unlimited"  >> /etc/security/limits.conf
}

#
#关闭selinux
#
selinux_disable()
{
    # 关闭selinux
#    if [ $(getenforce) = "Enabled" ]; then
#        setenforce 0||true
#    fi
    # selinux设置为disabled
#    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce  0 ||true
#    sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux
    sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
#    sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/sysconfig/selinux
    sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config
    getenforce
    echo "Selinux disabled success"
}

#
#关闭防火墙
#
firewalld_stop()
{
    # 关闭防火墙
    systemctl disable firewalld
    systemctl stop firewalld
    echo "Firewall disabled success"
}


etcd_install()
{
    systemctl stop etcd||true
    rm -rf /var/lib/etcd

    mkdir -p /var/lib/etcd
    cp -rf etcd_ca/etcd etcd_ca/etcdctl /usr/bin/
    ETCD_HOST_PORTS=$(awk  '{if($1 == "[k8s-node]"){exit}else{print $1}}' node.hosts |tail -n +2| awk -v ETCD_PROTOCOL=${ETCD_PROTOCOL} '{print "etcd"$1"="ETCD_PROTOCOL"://"$1":2380"}'|tr '\n' ','|sed 's/,$//')


    cat <<EOF >/lib/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/bin/etcd \\
    --name etcd${MASTER_ADDRESS} \\
    --initial-advertise-peer-urls ${ETCD_PROTOCOL}://${MASTER_ADDRESS}:2380 \\
    --listen-peer-urls ${ETCD_PROTOCOL}://${MASTER_ADDRESS}:2380 \\
    --listen-client-urls ${ETCD_PROTOCOL}://${MASTER_ADDRESS}:2379,${ETCD_PROTOCOL}://127.0.0.1:2379 \\
    --advertise-client-urls ${ETCD_PROTOCOL}://${MASTER_ADDRESS}:2379 \\
    --initial-cluster-token 9477af68bbee1b9ae037d6fd9e7efefd \\
    --initial-cluster ${ETCD_HOST_PORTS} \\
    --initial-cluster-state new \\
    --data-dir /var/lib/etcd \\
    --election-timeout 3000 \\
    --snapshot-count 100 \\
    --cert-file=/etc/etcd/ssl/etcd.pem \\
    --key-file=/etc/etcd/ssl/etcd-key.pem \\
    --peer-cert-file=/etc/etcd/ssl/etcd.pem \\
    --peer-key-file=/etc/etcd/ssl/etcd-key.pem \\
    --trusted-ca-file=/etc/etcd/ssl/ca.pem \\
    --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem \\
    --debug


Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


     systemctl daemon-reload
     systemctl disable etcd
     systemctl enable etcd
     echo "etcd is starting ..."
     systemctl restart etcd
     systemctl status -l etcd
     echo "etcd start ok"
}


#
#安装docker
#
docker_install()
{
	# step 1: 安装必要的一些系统工具
	mkdir -p ~/yum.repos
	mv -f /etc/yum.repos.d/* ~/yum.repos || true
	#curl -sSo /etc/yum.repos.d/aliyun-Centos-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo
	cp -f Centos-7.repo /etc/yum.repos.d/aliyun-Centos-7.repo
	cp -f docker-ce.repo /etc/yum.repos.d/docker-ce.repo
    install_rpm 'policycoreutils-python libseccomp ca-certificates  docker-ce-selinux-17.03.3.ce containerd.io docker-ce-17.03.3.ce' || true

	#sudo yum install -y yum-utils device-mapper-persistent-data lvm2
	# Step 2: 添加软件源信息
#	sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

	# Step 3: 更新并安装 Docker-CE
	#sudo yum makecache fast
    #查看docker版本
    #yum list docker-engine showduplicates
    #安装docker
    #yum install -y docker-engine-1.12.6-1.el7.centos.x86_64
	#rpm -qa |grep -P '(docker|container)'| xargs rpm -ehv || true  #rpm -ivh docker-ce-*
#	yum install -y docker-ce
	sudo rm -rf /var/lib/docker /etc/docker/*
	#yum install -y --setopt=obsoletes=0 docker-ce-17.03.1.ce-1.el7.centos docker-ce-selinux-17.03.1.ce-1.el7.centos
    echo "Docker installed successfully"

    #docker加速器
    if [ ! -n "$DOCKER_MIRRORS" ]; then
        export DOCKER_MIRRORS="https://5md0553g.mirror.aliyuncs.com"
    fi
    # 如果/etc/docker目录不存在，就创建目录
    if [ ! -d "/etc/docker" ]; then
     mkdir -p /etc/docker
    fi
    # 配置加速器
    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ["${DOCKER_MIRRORS}"],
    "graph":"${DOCKER_GRAPH}",
    "storage-driver": "overlay2",
    "storage-opts": [
	"overlay2.override_kernel_check=true"
  ]
}
EOF
    systemctl daemon-reload
    systemctl disable docker
    systemctl enable docker
    systemctl start docker
    systemctl status docker
    echo "Docker start successfully"

    docker load -i allinone.tar || true
    echo "Docker loads images successfully"

}


kube_rpm()
{
    if [ ! -n "$KUBE_VERSION" ]; then
        export KUBE_VERSION="1.9.1"
    fi
    if [ ! -n "$KUBE_CNI_VERSION" ]; then
        export KUBE_CNI_VERSION="0.6.0"
    fi
    if [ ! -n "$SOCAT_VERSION" ]; then
        export SOCAT_VERSION="1.7.3.2"
    fi
    export OSS_URL="http://centos-k8s.oss-cn-hangzhou.aliyuncs.com/rpm/"${KUBE_VERSION}"/"
    export RPM_KUBEADM="kubeadm-"${KUBE_VERSION}"-0.x86_64.rpm"
    export RPM_KUBECTL="kubectl-"${KUBE_VERSION}"-0.x86_64.rpm"
    export RPM_KUBELET="kubelet-"${KUBE_VERSION}"-0.x86_64.rpm"
    export RPM_KUBECNI="kubernetes-cni-"${KUBE_CNI_VERSION}"-0.x86_64.rpm"
    export RPM_SOCAT="socat-"${SOCAT_VERSION}"-2.el7.x86_64.rpm"
}

#
#配置docker镜像
#
kube_registry()
{
    if [ ! -n "$ETCD_VERSION" ]; then
        export ETCD_VERSION="3.1.10"
    fi
    if [ ! -n "$PAUSE_VERSION" ]; then
        export PAUSE_VERSION="3.0"
    fi
    if [ ! -n "$FLANNEL_VERSION" ]; then
        export FLANNEL_VERSION="v0.9.1"
    fi

    #KUBE_REPO_PREFIX环境变量已经失效，需要通过MasterConfiguration对象进行设置
    export KUBE_REPO_PREFIX=registry.cn-hangzhou.aliyuncs.com/szss_k8s
}


kube_install()
{
    # Kubernetes 1.8开始要求关闭系统的Swap，如果不关闭，默认配置下kubelet将无法启动。可以通过kubelet的启动参数–fail-swap-on=false更改这个限制。
    # 修改 /etc/fstab 文件，注释掉 SWAP 的自动挂载，使用free -m确认swap已经关闭。
    swapoff -a
    sed -i 's/.*swap.*/#&/' /etc/fstab #永久生效
    echo "Swap off success"

    # 设置swappiness参数为0，linux swap空间为0
    cat > /etc/sysctl.d/k8s.conf <<EOF
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.netfilter.nf_conntrack_max = 2310720
fs.inotify.max_user_watches=89100
#fs.may_detach_mounts = 1
fs.file-max = 52706963
fs.nr_open = 52706963
net.bridge.bridge-nf-call-arptables = 1
vm.swappiness = 0
vm.overcommit_memory=1
vm.panic_on_oom=0
EOF
    #其中必须配置有
#    net.bridge.bridge-nf-call-ip6tables = 1
#    net.bridge.bridge-nf-call-iptables = 1
#    vm.swappiness = 0
    ulimit  -SHn 655360
    modprobe br_netfilter
    #reboot生效
    sed -i '/ swap / s/^/#/' /etc/fstab
    # 生效配置
    sysctl -p /etc/sysctl.d/k8s.conf
    echo "Network configuration success"
    kube_rpm
    kube_registry

    rpm -ivh $PWD"/"$RPM_KUBECNI $PWD"/"$RPM_SOCAT $PWD"/"$RPM_KUBEADM $PWD"/"$RPM_KUBECTL $PWD"/"$RPM_KUBELET || true
    echo "kubelet kubeadm kubectl kubernetes-cni installed successfully"
    sed -i 's/cgroup-driver=systemd/cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    echo "config cgroup-driver=cgroupfs success"
    export KUBE_PAUSE_IMAGE=${KUBE_REPO_PREFIX}"/pause-amd64:${PAUSE_VERSION}"
    cat > /etc/systemd/system/kubelet.service.d/20-pod-infra-image.conf <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--v=2 --pod-infra-container-image=${KUBE_PAUSE_IMAGE}"
EOF
    echo "config --pod-infra-container-image=${KUBE_PAUSE_IMAGE} success"
    systemctl daemon-reload
    systemctl disable kubelet
    systemctl enable kubelet
    systemctl restart kubelet
    systemctl status -l kubelet
    #clean old cmd
    (kubectl completion bash)>source
    echo "(kubectl completion bash)>source" >> ~/.bashrc
    echo "Kubelet installed successfully"
}



#
#启动主节点
#
kube_master_up(){
    kube_rpm
    kube_registry
    # 如果使用etcd集群，请使用etcd.endpoints配置
    allowedIPs=$(awk '{if($1!="[k8s-node]" && $1!="[k8s-master]")print "    - "$1}' node.hosts)
    etcdIPPorts=$(awk -v PROT="${ETCD_PROTOCOL}"  '{if($1 == "[k8s-node]"){exit}else{print "    - "PROT"://"$1":2379"}}' node.hosts |tail -n +2)
    if [[ "$ETCD_PROTOCOL"=="https" ]]; then
        ETCD_CERTS="\
    caFile: /etc/etcd/ssl/ca.pem
    certFile: /etc/etcd/ssl/etcd.pem
    keyFile: /etc/etcd/ssl/etcd-key.pem
    dataDir: /var/lib/etcd
"
    else
        ETCD_CERTS=""
    fi
    cat <<EOF > /etc/kubernetes/kubeadm.conf
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
kubernetesVersion: v${KUBE_VERSION}
api:
    advertiseAddress: ${MASTER_VIP}
#    advertiseAddress: ${MASTER_ADDRESS}
#    controlPlaneEndpoint: "${MASTER_VIP}:8443"
networking:
    serviceSubnet: 10.96.0.0/12
    #此处的ip配置要与CNI中clusterCIDR参数配置的一致
    podSubnet: 192.168.0.0/16
imageRepository: ${KUBE_REPO_PREFIX}
tokenTTL: 0s
token: ${KUBE_TOKEN}
#etcd:
#    image: ${KUBE_ETCD_IMAGE}
etcd:
    endpoints:
${etcdIPPorts}
${ETCD_CERTS}
apiServerCertSANs:
    - 127.0.0.1
    - ${MASTER_VIP}
    - ${MASTER_ADDRESS}
    #hostnames
    - k8s.pub.sina.com.cn
    - k8s-174.cms.msina.yf.sinanode.com
    - k8s-56.cms.msina.yf.sinanode.com
    - k8s-58.cms.msina.yf.sinanode.com
${allowedIPs}
featureGates:
    #CoreDNS比kube-dns更加稳定，功能性更强
    CoreDNS: true
#---
#apiVersion: kubeproxy.config.k8s.io/v1alpha1
#kind: KubeProxyConfiguration
#mode: ipvs
#kubeProxy:
#  config:
#    # 这里可以选择用ipvs还是ipatables
#    mode: ipvs
#    # mode: iptables
EOF

    # 其他更多参数请通过kubeadm init --help查看
    # 参考：https://kubernetes.io/docs/reference/generated/kubeadm/
    kubeadm init --config /etc/kubernetes/kubeadm.conf  --ignore-preflight-errors=all

    echo "kubeadm code: $?"

    # $HOME/.kube目录不存在就创建
    if [ ! -d "$HOME/.kube" ]; then
        mkdir -p $HOME/.kube
    fi

    # $HOME/.kube/config文件存在就删除
    if [ -f "$HOME/.kube/config" ]; then
      rm -rf $HOME/.kube/config
    fi

    cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    echo "Config admin success"

    export CNI_PLUGIN="calico"
    (cd ${CNI_PLUGIN}; sh -x init.sh)

    echo "${CNI_PLUGIN} installed successfully, code $?"
}
install_base_plugins(){
    #为了测试我们把master 设置为 可部署role,默认情况下，为了保证master的安全，master是不会被调度到app的。你可以取消这个限制通过输入：
    #remove the taint
    kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule-
    kubectl apply --record -f ingress/ingress.yml || true
    kubectl apply --record -f dashboard-ui/kubernetes-dashboard.yaml
    sh dashboard-ui/show_token.sh  || true

    #在每个master上安装
    kubectl scale deployment/kubernetes-dashboard  -n kube-system --replicas=3
    kubectl scale deployment nginx-ingress-controller  -n ingress-nginx --replicas=3
    #add the taint
    kubectl taint nodes --all node-role.kubernetes.io/master=:NoSchedule
#    kubectl taint nodes k8s-174.cms.msina.yf.sinanode.com node-role.kubernetes.io/master=:NoSchedule
#    kubectl taint nodes k8s-56.cms.msina.yf.sinanode.com node-role.kubernetes.io/master=:NoSchedule
#    kubectl taint nodes k8s-58.cms.msina.yf.sinanode.com node-role.kubernetes.io/master=:NoSchedule

}
#
#启动子节点
#
kube_slave_up()
{
    kubeadm join  --token ${KUBE_TOKEN} \
    --discovery-token-unsafe-skip-ca-verification \
    --skip-preflight-checks \
    ${MASTER_VIP}:6443
    echo "Join kubernetes cluster success"
}
#
kube_reset_light()
{
    kube_reset_inner
    logger kube_reset_light

}

kube_reset_inner(){
    kubeadm reset -f || true
    systemctl stop kubelet  || true
    systemctl stop docker || true
    rm -rf /var/lib/cni/ || true
    rm -rf /var/lib/kubelet/* || true
    rm -rf /etc/cni/ || true
#    rm -rf /etc/kubernetes/ ||true
    ifconfig cni0 down || true
    ifconfig flannel.1 down || true
    ifconfig docker0 down || true
    ip link delete cni0 || true
    ip link delete flannel.1 || true
    ip link delete docker0|| true
    rm -rf ~/.kube/config


    sed -i -e  's/(kubectl completion bash)>source//g' ~/.bashrc

    #reset etcd
    ETCDCTL_API=3 etcdctl del "" --prefix=true --endpoints=https://${MASTER_ADDRESS}:2379  \
  --cacert=/etc/etcd/ssl/ca.pem \
  --cert=/etc/etcd/ssl/etcd.pem \
  --key=/etc/etcd/ssl/etcd-key.pem || true
    #reset calico
    ip route flush proto bird || true
    ip link list | grep cali | awk '{print $2}' | cut -c 1-15 | xargs -I {} ip link delete {} || true
    rm /etc/cni/net.d/10-calico.conflist && rm /etc/cni/net.d/calico-kubeconfig || true
}

#
# 重置集群
#
kube_reset()
{
    kube_reset_inner
#    (docker ps -a |awk '{print $1}' |xargs docker rm -f) || true
    rm -rf  /run/flannel/subnet.env /etc/kubernetes/kubeadm.conf /etc/kubernetes
#    docker system prune -af
#    rm -rf ${DOCKER_GRAPH}
    # 删除rpm安装包
    yum remove -y kubectl kubeadm kubelet kubernetes-cni socat docker-ce docker-ce-selinux containerd containerd.io etcd   container-selinux
    logger kube_reset
}


kube_help()
{
    echo "usage: $0 --node-type master --master-address 127.0.0.1 --token xxxx"
    echo "       $0 --node-type node --master-address 127.0.0.1 --token xxxx"
    echo "       $0 reset     reset the kubernetes cluster,include all data"
    echo "       unkown command $0 $@"
}


main()
{
    #系统检测
    #$# 查看这个程式的参数个数
    while [[ $# -gt 0 ]]
    do
        #获取第一个参数
        key="$1"

        case $key in
            #主节点IP
            --master-address)
                export MASTER_ADDRESS=$2
                #向左移动位置一个参数位置
                shift
            ;;
            --master-vip)
                export MASTER_VIP=$2
                #向左移动位置一个参数位置
                shift
            ;;
            #获取docker存储路径
            --docker-graph)
                export DOCKER_GRAPH=$2
                #向左移动位置一个参数位置
                shift
            ;;
            #获取docker加速器地址
            --docker-mirrors)
                export DOCKER_MIRRORS=$2
                #向左移动位置一个参数位置
                shift
            ;;
            #获取节点类型
            -n|--node-type)
                export NODE_TYPE=$2
                #向左移动位置一个参数位置
                shift
            ;;
            #获取kubeadm的token
            -t|--token)
                export KUBE_TOKEN=$2
                #向左移动位置一个参数位置
                shift
            ;;
            #重置集群
            kube_reset_light)
                kube_reset_light
                exit
            ;;
            #重置集群
            kube_reset_inner)
                kube_reset_inner
                exit
            ;;
            #重置集群
            r|kube_reset)
                kube_reset
                exit
            ;;
            etcd_install)
                etcd_install
                exit
            ;;
            install_base_plugins)
                install_base_plugins
                exit
            ;;
            install_kubelet)
                    linux_os
                    #关闭selinux
                    selinux_disable
                    #关闭防火墙
                    firewalld_stop
                    #安装docker
                    docker_install
                    #安装RPM包
                    kube_install
                exit
            ;;
            "mod" | "module" )
                kubectl apply --record -f ingress/ingress.yml -f dashboard-ui/kubernetes-dashboard.yaml
                exit
            ;;
            #获取kubeadm的token
            -h|--help)
                kube_help
                exit 1
            ;;
            *)
                # unknown option
                echo "unkonw option [$key]"
            ;;
        esac
        shift
    done

    if [ "" == "$MASTER_ADDRESS" -o "" == "$NODE_TYPE" ];then
        if [ "$NODE_TYPE" != "down" ];then
            echo "--master-address and --node-type must be provided"
            exit 1
        fi
    fi

 case $NODE_TYPE in
    "m" | "master" )
        kube_master_up
        ;;
    "n" | "node" )
        kube_slave_up
        ;;
    *)
        kube_help
        ;;
 esac
}

main $@
