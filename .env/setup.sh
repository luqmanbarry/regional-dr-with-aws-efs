#!/bin/bash

ACTION="$1"

if [ "$ACTION" = "-h" ] || [ "$ACTION" = "--help" ];
then
  echo "Example Call: . .env/setup.sh"
fi

export ANSIBLE_ENV_DIR=".ansible-venv"


# Validate Inputs are provided
if ! test -f $ANSIBLE_ENV_DIR/bin/activate ;
then
  # ln -s /usr/bin/python3.11 /usr/bin/python
  # ln -s /usr/bin/python3.11 /usr/bin/python3
  # Create Python Env
  pip3.11 --upgrade pip
  pip3.11 --version
  pip3.11 install --user virtualenv

  virtualenv $ANSIBLE_ENV_DIR
  
  echo "Created virtual environment: "
  ls -latr $ANSIBLE_ENV_DIR
  ls -latr $ANSIBLE_ENV_DIR/bin
  echo "Current Directory: $(pwd)"
  echo "Current Directory Content: $(ls -latr)"

  deactivate || echo "Ansible Virtual Environment not active"
  . $(pwd)/$ANSIBLE_ENV_DIR/bin/activate || echo 'Failed to enter Ansible Virtual Environment'

  pip3.11 install -U \
    ansible \
    kubernetes \
    jsonpatch \
    pyyaml \
    jmespath \
    kubernetes-validate \
    openshift \
    openshift-client
    
  pip3.11 list

  ansible --version

  ansible-galaxy collection install kubernetes.core
  ansible-galaxy collection install  community.general
  ansible-galaxy collection install  ansible.posix
  
  ansible-galaxy collection list community.general
  ansible-galaxy collection list kubernetes.core
  ansible-galaxy collection list ansible.posix
fi

deactivate || echo "Ansible Virtual Environment not active"
. $(pwd)/$ANSIBLE_ENV_DIR/bin/activate || echo 'Failed to activate Ansible Virtual Environment'
