sudo mkdir -p /data1/ms/

cd /data1/ms && sudo git clone 'https://cmsdev:!!Yhb6sqt!!@git.staff.sina.com.cn/cms/backend/k8s.git'



#cd /data1/ms/k8s && sudo git pull


sudo sh /data1/ms/k8s/centos_init/init.sh


ansible k8s-node -a 'cd /data1/ms/k8s && sh -x k8s.sh --master-address 10.79.217.185 --node-type node'


ansible k8s-master -a 'cd /data1/ms/k8s && sh -x k8s.sh --master-address 10.79.217.185 --node-type master'


ansible-playbook /data1/ms/k8s/centos_init/ansible/k8s.playbook.yml --start-at="install node"

10.79.40.174,10.73.14.145,10.73.14.148,10.39.40.138,10.41.14.200