variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for the EKS cluster"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for EKS encryption"
  type        = string
}

variable "domain_name" {
  description = "Domain name for TLS certificate"
  type        = string
}

variable "organization_name" {
  description = "Organization name for the certificate subject"
  type        = string
}

variable "node_group_name" {
  description = "Name of the EKS Node Group"
  type        = string
}

variable "node_role_arn" {
  description = "ARN for the node group IAM role"
  type        = string
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
}

variable "node_instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
}
