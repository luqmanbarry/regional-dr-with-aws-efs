#!/bin/bash

ACTION="$1"
ENV_DIR=".ansible-venv"


# Validate Inputs are provided
if ! test -f $ENV_DIR/bin/activate ;
then
  # ln -s /usr/bin/python3.11 /usr/bin/python
  # ln -s /usr/bin/python3.11 /usr/bin/python3
  # Create Python Env
  pip3.11 --upgrade pip
  pip3.11 --version
  pip3.11 install --user virtualenv

  virtualenv $ENV_DIR
  
  echo "Created virtual environment: "
  ls -latr $ENV_DIR
  ls -latr $ENV_DIR/bin
  echo "Current Directory: $(pwd)"
  echo "Current Directory Content: $(ls -latr)"

  echo "deactivate || true"
  echo ". \"$(pwd)/$ENV_DIR/bin/activate\" || echo 'Failed to enter virtual environment' && exit 1"

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

  ansible-galaxy collection install \
    kubernetes.core \
    community.kubernetes \
    community.general \
    ansible.posix \
  
  ansible-galaxy collection list \
    community.general \
    # kubernetes.core \
    community.kubernetes \
    ansible.posix
fi

