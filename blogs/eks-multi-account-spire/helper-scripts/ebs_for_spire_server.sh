export EBS_CSI_POLICY_NAME="Amazon_EBS_CSI_Driver_For_Spire_Server"


# download the IAM policy document
curl -sSL -o ebs-csi-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/docs/example-iam-policy.json

# Create the IAM policy
aws iam create-policy \
  --profile shared \
  --policy-name ${EBS_CSI_POLICY_NAME} \
  --policy-document file://ebs-csi-policy.json

# export the policy ARN as a variable
export EBS_CSI_POLICY_ARN=$(aws --profile shared iam list-policies --query 'Policies[?PolicyName==`'$EBS_CSI_POLICY_NAME'`].Arn' --output text)

# Create a service account
eksctl create iamserviceaccount \
  --cluster eks-cluster-shared \
  --name spire-server \
  --profile shared \
  --namespace kube-system \
  --attach-policy-arn $EBS_CSI_POLICY_ARN \
  --override-existing-serviceaccounts \
  --approve

# add the aws-ebs-csi-driver as a helm repo
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver

helm upgrade --install aws-ebs-csi-driver \
  --version=1.2.4 \
  --namespace kube-system \
  --set serviceAccount.controller.create=false \
  --set serviceAccount.snapshot.create=false \
  --set enableVolumeScheduling=true \
  --set enableVolumeResizing=true \
  --set enableVolumeSnapshot=true \
  --set serviceAccount.snapshot.name=spire-server \
  --set serviceAccount.controller.name=spire-server \
  aws-ebs-csi-driver/aws-ebs-csi-driver

kubectl -n kube-system rollout status deployment ebs-csi-controller