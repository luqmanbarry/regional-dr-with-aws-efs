#!/bin/bash

echo '********************************************************'
echo '*****************  VOLUME CREATE  **********************'
echo '********************************************************'
echo

# . .ci/admin-inputs.sh
# . .ci/user-inputs.sh

echo '********************************************************'
echo '******  Launch the Ansible Virtual Environment  ********'
echo '********************************************************'
echo


echo '********************************************************'
echo '**********  Ansible: Initiate Volume Create  ***********'
echo '********************************************************'
echo

ansible-playbook volume-create.yaml \
  -e @vars/inputs.yaml \
  -e "pv_git_commit_token=\"$pv_git_commit_token\"" \
  -e "pv_git_commit_repository=\"$pv_git_commit_repository\"" \
  -e "ocp_primary_login_command=\"$ocp_primary_login_command\"" \
  -e "efs_primary_hostname=\"$efs_primary_hostname\"" \
  -e "business_unit=\"$business_unit\"" \
  -e "ocp_primary_cluster_name=\"$ocp_primary_cluster_name\"" \
  -e "application_name=\"$application_name\"" \
  -e "namespace=\"$namespace\"" \
  -e "pvc_name=\"$pvc_name\"" \
  -e "pvc_size=\"$pvc_size\"" \
  -e "pv_enable_multi_mount=\"$pv_enable_multi_mount\"" \
  -vv | tee volume-create.log