#!/bin/bash

sudo dnf install -y \
  python3.11 \
  python3.11-pip \
  ansible-core \
  nfs-utils \
  nmap \
  tree \
  jq \
  unzip

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

eval $(ssh-agent -s)

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

OCP_CLUSTER_DOMAIN="apps.rosa-primary.zd0h.p1.openshiftapps.com" # Change this to your cluster domain
curl -O "https://downloads-openshift-console.$OCP_CLUSTER_DOMAIN/amd64/linux/oc.tar"
tar xvf oc.tar
sudo cp -Zv oc /usr/local/bin
rm -rf oc oc.tar
