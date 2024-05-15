#!/bin/bash

echo '********************************************************'
echo '*****************  VOLUME CREATE  **********************'
echo '********************************************************'
echo

export ANSIBLE_ENV_DIR=".ansible-venv"

# . .ci/admin-inputs.sh
# . .ci/user-inputs.sh

echo '********************************************************'
echo '******  Launch the Ansible Virtual Environment  ********'
echo '********************************************************'
echo

. .env/setup.sh

# echo ". $(pwd)/$ANSIBLE_ENV_DIR/bin/activate || echo 'Failed to enter virtual environment'"

echo '********************************************************'
echo '**********  Ansible: Initiate Volume Create  ***********'
echo '********************************************************'
echo

ansible-playbook volume-create.yaml \
  -e @vars/inputs.yaml \
  -e "pv_git_commit_token=\"$pv_git_commit_token\"" \
  -e "pv_git_commit_repository=\"$pv_git_commit_repository\"" \
  -e "ocp_login_command=\"$ocp_login_command\"" \
  -e "src_efs_hostname=\"$src_efs_hostname\"" \
  -e "business_unit=\"$business_unit\"" \
  -e "cluster_name=\"$cluster_name\"" \
  -e "application_name=\"$application_name\"" \
  -e "namespace=\"$namespace\"" \
  -e "pvc_name=\"$pvc_name\"" \
  -e "pvc_size=\"$pvc_size\"" \
  -e "pv_enable_multi_mount=\"$pv_enable_multi_mount\"" \
  -v | tee volume-create.log

echo "deactivate || true"