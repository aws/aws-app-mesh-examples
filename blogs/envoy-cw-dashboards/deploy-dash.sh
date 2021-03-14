mkdir -p $DIR/_output
CLOUDWATCH_NAMESPACE="AppMeshExample/gateway-envoy/StatsD"
MESH_NAME="<Name of your AppMesh>"
VIRTUAL_NODE_NAME="<Name of your Virtual Node"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PROJECT_NAME="$(basename ${DIR})"

eval "cat <<EOF
$(<${DIR}/cw-dashboard.yaml.template)
EOF
" >$DIR/_output/${VIRTUAL_NODE_NAME}-cw-dashboard.yaml

        echo "Deploying stack ${VIRTUAL_NODE_NAME}-cw-dashboard, this may take a few minutes..."
        aws cloudformation deploy \
            --no-fail-on-empty-changeset \
            --stack-name ${PROJECT_NAME}-${VIRTUAL_NODE_NAME} \
            --template-file "$DIR/_output/$VIRTUAL_NODE_NAME-cw-dashboard.yaml" \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides \
            "DashboardName=${PROJECT_NAME}-${VIRTUAL_NODE_NAME}"