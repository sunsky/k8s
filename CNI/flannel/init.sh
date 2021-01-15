#!/usr/bin/env bash
#    if [ -f "$HOME/kube-flannel.yml" ]; then
#        rm -rf $HOME/kube-flannel.yml
#    fi
#    wget -P $HOME/ https://raw.githubusercontent.com/coreos/flannel/${FLANNEL_VERSION}/Documentation/kube-flannel.yml
    cp -f ./kube-flannel-0.9.1.yml ./kube-flannel.yml
#    sed -i 's/quay.io\/coreos\/flannel/registry.cn-hangzhou.aliyuncs.com\/szss_k8s\/flannel/g' $HOME/kube-flannel.yml
    kubectl --namespace kube-system apply -f ./kube-flannel.yml||true
