#!/bin/bash

echo '********************************************************'
echo '*****************  VOLUME RESTORE  *********************'
echo '********************************************************'
echo

ENV_DIR=".ansible-venv"

# . .ci/admin-inputs.sh
# . .ci/user-inputs.sh

echo '********************************************************'
echo '******  Launch the Ansible Virtual Environment  ********'
echo '********************************************************'
echo

. .env/setup.sh

# echo ". $(pwd)/$ENV_DIR/bin/activate || echo 'Failed to enter virtual environment'"

echo '********************************************************'
echo '**********  Ansible: Initiate Volume Restore  **********'
echo '********************************************************'
echo

ansible-playbook volume-restore.yaml \
  -e @vars/inputs.yaml \
  -e "pv_git_commit_token=\"$pv_git_commit_token\"" \
  -e "pv_git_commit_repository=\"$pv_git_commit_repository\"" \
  -e "ocp_login_command=\"$ocp_login_command\"" \
  -e "src_efs_hostname=\"$src_efs_hostname\"" \
  -e "dest_efs_hostname=\"$dest_efs_hostname\"" \
  -v | tee volume-restore.log

echo "deactivate || true"