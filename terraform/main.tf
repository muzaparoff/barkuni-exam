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

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "barkuni-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "production"
    Project     = "barkuni"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "barkuni-cluster-${random_string.suffix.result}"
  cluster_version = "1.27"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      desired_size = 2
      min_size     = 1
      max_size     = 3

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "production"
    Project     = "barkuni"
  }
}

# Create self-signed certificate
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

# Reference the existing Route53 hosted zone for vicarius.xyz
data "aws_route53_zone" "main" {
  name         = "vicarius.xyz."
  private_zone = false
}

# Use the existing zone's ID for records
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.eks.cluster_endpoint
    zone_id                = module.eks.cluster_arn
    evaluate_target_health = true
  }
}

# Create IAM role for ALB Ingress Controller
resource "aws_iam_role" "alb_ingress_controller" {
  name = "eks-alb-ingress-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com",
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# Attach ALB Ingress Controller policy to the role
resource "aws_iam_role_policy" "alb_ingress_controller" {
  name = "alb-ingress-controller"
  role = aws_iam_role.alb_ingress_controller.id

  policy = file("${path.module}/policies/alb-ingress-policy.json")
}

# Create Kubernetes service account for ALB Ingress Controller
resource "kubernetes_service_account" "alb_ingress_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_ingress_controller.arn
    }
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  log_group_name = "/aws/eks/barkuni-cluster-${random_string.suffix.result}-${replace(timestamp(), ":", "")}/cluster"
}

resource "aws_cloudwatch_log_group" "eks" {
  name = local.log_group_name

  retention_in_days = 7

  tags = {
    Environment = "production"
    Project     = "barkuni"
  }
}

resource "aws_kms_key" "eks" {
  description = "EKS cluster ${module.eks.cluster_name} KMS key"

  deletion_window_in_days = 10

  tags = {
    Environment = "production"
    Project     = "barkuni"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/eks/barkuni-cluster-${random_string.suffix.result}"
  target_key_id = aws_kms_key.eks.id
}