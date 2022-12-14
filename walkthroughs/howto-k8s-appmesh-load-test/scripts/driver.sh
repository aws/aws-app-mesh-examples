err() {
    msg="Error: $1"
    echo "${msg}"
    code=${2:-"1"}
    exit ${code}
}

exec_command() {
  eval "$1"
  if [ $? -eq 0 ]; then
      echo "'$1' command Executed Successfully"
  else
      err "'$1' command Failed"
  fi
}

check_version() {
  eval "$1"
}

# sanity check
if [ -z "${CONTROLLER_PATH}" ]; then
    err "CONTROLLER_PATH is not set"
fi

if [ -z "${KUBECONFIG}" ]; then
    err "KUBECONFIG is not set"
fi

if [ -z "${CLUSTER_NAME}" ]; then
    err "CLUSTER_NAME is not set"
fi

if [ -z "${AWS_REGION}" ]; then
    err "AWS_REGION is not set"
fi

if [ -z "${VPC_ID}" ]; then
    err "VPC_ID is not set"
fi

# Check creds
if [ -n "${USER}" ]; then
  check_version "isengardcli version"
  if [ $? -eq 0 ]
  then
    eval "$(isengardcli creds "$USER")"
    status=$?
    [ $status -eq 0 ] && echo "Ran isengard creds successfully!" || (err "isengard creds error.")
  fi
fi

# Install python3 dependencies
exec_command "python3 --version"

declare -a libraries=("boto3" "numpy" "pandas" "requests" "botocore" "matplotlib")

for i in "${libraries[@]}"
do
  check_version "pip3 show $i"
  if [ $? -ne 0 ]
  then
       exec_command "pip3 install $i"
  fi
done

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
APPMESH_LOADTESTER_PATH="$(dirname "$DIR")"
echo "APPMESH_LOADTESTER_PATH -: $APPMESH_LOADTESTER_PATH"

# Prometheus port forward
echo "Port-forwarding Prometheus"
kubectl --namespace appmesh-system port-forward service/appmesh-prometheus 9090 &
pid=$!

# call ginkgo
echo "Starting Ginkgo test"
cd $CONTROLLER_PATH && ginkgo -v -r --focus "DNS" "$CONTROLLER_PATH"/test/e2e/fishapp/load -- --cluster-kubeconfig=$KUBECONFIG \
--cluster-name=$CLUSTER_NAME --aws-region=$AWS_REGION --aws-vpc-id=$VPC_ID \
--base-path=$APPMESH_LOADTESTER_PATH

# kill prometheus port forward
echo "Killing Prometheus port-forward"
kill -9 $pid
[ $status -eq 0 ] && echo "Killed Prometheus port-forward" || echo "Error when killing Prometheus port forward"