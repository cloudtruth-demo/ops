#!/usr/bin/env bash

# fail fast
set -e

function usage {
  echo "usage: $(basename $0) [-s eks_admin_role] environment cluster"
  echo
  echo "  Options:"
  echo
  echo "    -s eks_admin_role_secret  The dashboard admin role secret containing the access token"
  echo
  exit 1
}

admin_role="kubernetes-dashboard-token"

while getopts ":s:" opt; do
  case $opt in
    s)
      admin_role="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [[ $# != 2 ]]; then
  usage
fi

env=$1
cluster=$2

cat <<-'EOF' | atmos -e ${env} auth_exec bash -se "${cluster}" "${admin_role}"
  set -m
  admin_secret=$(kubectl --context "${1}" -n kubernetes-dashboard get secret | grep "${2}" | awk '{print $1}')
  kubectl --context "${1}" -n kubernetes-dashboard describe secret $admin_secret
  kubectl --context "${1}" proxy &
  sleep 1
  open http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:https/proxy/#/login
  fg %%
EOF
