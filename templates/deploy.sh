#!/bin/bash

NS="solrcloud1"

# Namespace
kubectl create namespace $NS

#
# Zookeeper
#

# Node Affinity Label
kubectl label nodes k8s-worker-node1 target_zkensemble=yes 
kubectl label nodes k8s-worker-node2 target_zkensemble=yes
kubectl label nodes k8s-worker-node3 target_zkensemble=yes

# Persistente Storage
kubectl create -f templates/zkensemble-storageclass.yaml
kubectl create -f templates/zkensemble-persistentVolume.yaml

# Headless Service
kubectl create -f templates/zkensemble-service-headless.yaml

# ConfigMap & StatefulSet in target Namespace
kubectl --namespace=$NS create configmap zkensemble-config --from-env-file=templates/zkensemble-configmap.properties 
kubectl --namespace=$NS create -f templates/zkensemble-statefulset.yaml

#
# SolrCloud
#

# Node Affinity Label
kubectl label nodes k8s-worker-node1 target_solrcloud=yes
kubectl label nodes k8s-worker-node2 target_solrcloud=yes
kubectl label nodes k8s-worker-node3 target_solrcloud=yes

# Persistente Storage
kubectl create -f templates/solrcloud-storageclass.yaml
kubectl create -f templates/solrcloud-persistentVolume.yaml

# Headless Service
kubectl create -f templates/solrcloud-service-headless.yalm

# ConfigMap & StatefulSet in target Namespace
kubectl --namespace=$NS create configmap solrcloud-config --from-env-file=templates/solrcloud-configmap.properties 
kubectl --namespace=$NS create -f templates/solrcloud-statefulset.yaml
