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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = "1.27"

  vpc_id     = data.aws_vpc.main.id
  subnet_ids = data.aws_subnets.main.ids

  # Disable creation of KMS key/alias and CloudWatch log group
  create_kms_key          = false
  create_cloudwatch_log_group = false

  # Use your existing KMS key for encryption
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = data.aws_kms_key.eks.arn
  }

  # Enable logging and specify the existing log group
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = null # Not needed since you are not creating it

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
  depends_on = [module.eks]
}