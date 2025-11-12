# AWS-Infrastructure-Final-Project


ROLE_ARN=$(aws iam get-role \
  --role-name aws-final-project-eks-ebs-csi-driver-role \
  --query "Role.Arn" --output text)

kubectl annotate serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite

kubectl -n kube-system delete pod -l app=ebs-csi-controller