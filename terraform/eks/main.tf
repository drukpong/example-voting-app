
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.68.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name = "availability-zone"
    values = [
      "us-east-1a",
      "us-east-1b",
      "us-east-1c",
      "us-east-1d",
      "us-east-1f"
    ]
  }
}

# EKS control-plane IAM role
resource "aws_iam_role" "eks_cluster" {
  name = "devops-capstone-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = "DevOpsCapstone"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Kubernetes control plane
resource "aws_eks_cluster" "capstone" {
  name     = "devops-capstone-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.34"

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = data.aws_subnets.default.ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["98.97.76.77/32"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Project = "DevOpsCapstone"
  }
}

# Worker-node IAM role
resource "aws_iam_role" "eks_nodes" {
  name = "devops-capstone-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = "DevOpsCapstone"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# Managed worker nodes
resource "aws_eks_node_group" "capstone" {
  cluster_name    = aws_eks_cluster.capstone.name
  node_group_name = "devops-capstone-workers"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = ["t3.small"]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy
  ]

  tags = {
    Project = "DevOpsCapstone"
  }
}
