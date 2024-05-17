#!/bin/bash

echo '********************************************************'
echo '*****************  VOLUME RESTORE  *********************'
echo '********************************************************'
echo

# . .ci/admin-inputs.sh
# . .ci/user-inputs.sh

echo '********************************************************'
echo '******  Launch the Ansible Virtual Environment  ********'
echo '********************************************************'
echo

echo '********************************************************'
echo '**********  Ansible: Initiate Volume Restore  **********'
echo '********************************************************'
echo

ansible-playbook volume-restore.yaml \
  -e @vars/inputs.yaml \
  -e "pv_git_commit_token=\"$pv_git_commit_token\"" \
  -e "pv_git_commit_repository=\"$pv_git_commit_repository\"" \
  -e "ocp_primary_cluster_name=\"$ocp_primary_cluster_name\"" \
  -e "ocp_secondary_login_command=\"$ocp_secondary_login_command\"" \
  -e "efs_primary_hostname=\"$efs_primary_hostname\"" \
  -e "efs_secondary_hostname=\"$efs_secondary_hostname\"" \
  -v | tee volume-restore.log