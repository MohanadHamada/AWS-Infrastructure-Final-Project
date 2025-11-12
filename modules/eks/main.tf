# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.private_subnets
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# IAM Role for Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach IAM Policies for Worker Nodes
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Custom EBS CSI Driver Policy
resource "aws_iam_policy" "ebs_csi_custom_policy" {
  name        = "${var.cluster_name}-ebs-csi-policy"
  description = "Custom EBS CSI Driver permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "ec2:DescribeVolumes",
          "ec2:DeleteVolume",
          "ec2:DetachVolume"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_ebs_csi_custom" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.ebs_csi_custom_policy.arn
}

# Node Group
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  instance_types = [var.instance_type]

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy
  ]
}

# --- Configure Kubernetes provider after EKS cluster creation ---
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks_cluster.name
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks_cluster.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# Map IAM users and node role for cluster access
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapUsers = yamlencode([
      for user_arn in var.eks_admin_users : {
        userarn  = user_arn
        username = replace(split("/", user_arn)[1], "-", "_")
        groups   = ["system:masters"]
      }
    ])

    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.eks_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy
  ]
}

resource "null_resource" "install_ebs_csi_driver" {
  depends_on = [aws_eks_node_group.eks_nodes]

  provisioner "local-exec" {
    command = "aws eks --region us-east-1 update-kubeconfig --name aws-final-project-eks && kubectl apply -k 'github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.12'"
  }
}