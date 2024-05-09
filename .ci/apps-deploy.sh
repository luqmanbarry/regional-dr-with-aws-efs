#!/bin/bash

echo '********************************************************'
echo '**************  SAMPLE APPS DEPLOY  ********************'
echo '********************************************************'
echo

echo '********************************************************'
echo '*********  CHECK REQUIRED PROGRAM INSTALLED  ***********'
echo '********************************************************'
echo

if ! [ -x "$(oc version --client)" ]; then
  echo 'Error: openshift-client is not installed.' >&2
  exit 1
fi

if ! [ -x "$(helm version)" ]; then
  echo 'Error: helm is not installed.' >&2
  exit 1
fi

if ! [ -x "$(oc whoami)" ]; then
  echo 'Error: User is not signed in to OpenShift.' >&2
  exit 1
fi

echo '********************************************************'
echo '**************  DEPLOY MICRO SERVICES  *****************'
echo '********************************************************'
echo
helm upgrade --install regional-dr-apps ./sample-apps
echo
helm list