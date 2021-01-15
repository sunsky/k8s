#!/usr/bin/env bash
kubectl config set-credentials cms --username=cmsdev --password=password123
kubectl config set-cluster cms-k8s --server=https://172.16.114.58:6443
kubectl config set-context default-context --cluster=cms-k8s--user=myself
kubectl config use-context default-context
kubectl config set contexts.default-context.namespace cms-k8s
kubectl config view