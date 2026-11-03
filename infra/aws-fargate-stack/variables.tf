variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "eshop"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 public hosted zone ID to create records in."
  default     = "Z08283382I9QOAU3X7M20" # denver-innovation-lab.slalomdev.io
}

variable "domain" {
  type        = string
  description = "Base domain (the hosted zone name without trailing dot)."
  default     = "denver-innovation-lab.slalomdev.io"
}

variable "subdomain_webapp" {
  type    = string
  default = "eshop"
}

variable "subdomain_identity" {
  type    = string
  default = "eshop-id"
}

variable "subdomain_bff" {
  type    = string
  default = "eshop-bff"
}

# Backing-store credentials. Defaults are fine for a reference app; override
# via a tfvars or TF_VAR_* for anything you care about.
variable "postgres_user" {
  type    = string
  default = "postgres"
}

variable "postgres_password" {
  type      = string
  sensitive = true
  default   = "Pass@word1"
}

variable "rabbitmq_user" {
  type    = string
  default = "guest"
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
  default   = "guest"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "eShop"
    ManagedBy = "terraform"
    Stack     = "fargate-full"
  }
}
