#!/bin/bash

ACTION="$1"

if [ "$ACTION" = "-h" ] || [ "$ACTION" = "--help" ];
then
  echo "Example Call: . .env/setup.sh"
fi

export ANSIBLE_ENV_DIR="$(pwd)/.ansible-venv"


# Validate Inputs are provided
if ! test -f ${ANSIBLE_ENV_DIR}/bin/activate ;
then
  # ln -s /usr/bin/python3.11 /usr/bin/python
  # ln -s /usr/bin/python3.11 /usr/bin/python3
  # Create Python Env
  pip3.11 --upgrade pip
  pip3.11 --version
  pip3.11 install --user virtualenv

  virtualenv ${ANSIBLE_ENV_DIR}
  chmod -R 777 ${ANSIBLE_ENV_DIR}
  
  echo "Created virtual environment: "
  ls -latr ${ANSIBLE_ENV_DIR}
  ls -latr ${ANSIBLE_ENV_DIR}/bin
  echo "Current Directory: $(pwd)"
  echo "Current Directory Content: $(ls -latr)"

  deactivate || echo "Ansible Virtual Environment not active"
  . ${ANSIBLE_ENV_DIR}/bin/activate || echo 'Failed to enter Ansible Virtual Environment'

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

  ansible-galaxy collection install -r .env/requirements.yaml

fi

deactivate || echo "Ansible Virtual Environment not active"
. ${ANSIBLE_ENV_DIR}/bin/activate || echo 'Failed to enter Ansible Virtual Environment'