variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "zone_name" {
  description = "Route53 zone name (e.g. vicarius.xyz.)"
  type        = string
}

variable "domain_name" {
  description = "Full domain name for the app (e.g. app.vicarius.xyz)"
  type        = string
}

variable "nginx_lb_dns_name" {
  description = "The DNS name of the NGINX Ingress Controller's AWS LoadBalancer"
  type        = string
}
