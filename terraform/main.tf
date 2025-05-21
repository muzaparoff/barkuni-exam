terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Reference existing EKS cluster
data "aws_eks_cluster" "main" {
  name = "barkuni-exam-cluster"
}

data "aws_eks_cluster_auth" "main" {
  name = data.aws_eks_cluster.main.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

data "aws_vpc" "main" {
  id = "vpc-02fb1f16ffa2c1a11"
}

data "aws_subnets" "main" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

data "aws_cloudwatch_log_group" "eks" {
  name = "/aws/eks/barkuni-exam-cluster/cluster"
}

data "aws_kms_key" "eks" {
  key_id = "arn:aws:kms:us-east-1:058264138725:key/c600ebf9-94ec-4cf6-9e5a-1403967190d2"
}

data "aws_route53_zone" "main" {
  name         = "vicarius.xyz."
  private_zone = false
}

# Add this data source to get the OIDC provider for the cluster
data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "tls_private_key" "cert" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "cert" {
  private_key_pem = tls_private_key.cert.private_key_pem

  subject {
    common_name  = var.domain_name
    organization = "Barkuni"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_iam_role" "alb_ingress_controller" {
  name = "eks-alb-ingress-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com",
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "alb_ingress_controller" {
  name = "alb-ingress-controller"
  role = aws_iam_role.alb_ingress_controller.id

  policy = file("${path.module}/policies/alb-ingress-policy.json")
}

resource "kubernetes_service_account" "alb_ingress_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_ingress_controller.arn
    }
  }
  depends_on = [aws_iam_role.alb_ingress_controller]
}

# Try to find an existing node group named "general"
data "aws_eks_node_group" "general" {
  cluster_name    = data.aws_eks_cluster.main.name
  node_group_name = "general"
  # If not found, this will error, so we use 'count' logic below
  count = 0 # Only used for reference, not for creation
}

resource "aws_eks_node_group" "general" {
  count           = length(try(data.aws_eks_node_group.general.id, "")) == 0 ? 1 : 0
  cluster_name    = data.aws_eks_cluster.main.name
  node_group_name = "general"
  node_role_arn   = "arn:aws:iam::058264138725:role/general-eks-node-group-20250520133836818000000001"
  subnet_ids      = data.aws_subnets.main.ids

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  instance_types = ["t3.medium"]

  tags = {
    Environment = "production"
    Project     = "barkuni"
  }
}