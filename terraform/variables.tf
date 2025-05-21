variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable project_name {
  description = "Project name for tagging resources"
  type        = string
  default     = "barkuni-exam"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "barkuni.example.com"
}