variable "aws_region" {
  type        = string
  description = "AWS region to operate in."
  default     = "us-east-1"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in owner/name form that is allowed to assume the role."
  default     = "dwong-slalom/eShop"
}

variable "allowed_git_refs" {
  type        = list(string)
  description = "Git refs (relative to the repo) allowed to assume the role. Default: main branch only."
  default     = ["refs/heads/main"]
}

variable "create_oidc_provider" {
  type        = bool
  description = "Create the GitHub OIDC provider. Set false if it already exists in this account (then import or reference it)."
  default     = true
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role GitHub Actions will assume."
  default     = "github-actions-eshop-deploy"
}

# --- Fargate stack (fargate.tf) ---

variable "vpc_id" {
  type        = string
  description = "VPC the Fargate service runs in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Public subnets for the Fargate service (assign_public_ip = true)."
}

variable "ecr_repo_name" {
  type        = string
  description = "ECR repository name for the webapp image."
  default     = "eshop/webapp"
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name."
  default     = "eshop"
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service name (also used as the task definition family)."
  default     = "eshop-webapp"
}

variable "container_name" {
  type        = string
  description = "Container name inside the task definition."
  default     = "webapp"
}

variable "task_execution_role_name" {
  type        = string
  description = "Name of the ECS task execution role."
  default     = "eshop-ecs-task-execution"
}

variable "task_role_name" {
  type        = string
  description = "Name of the ECS task role."
  default     = "eshop-ecs-task"
}

variable "desired_count" {
  type        = number
  description = "Number of running tasks. 0 = defined but not running (no Fargate charges)."
  default     = 0
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default = {
    Project   = "eShop"
    ManagedBy = "terraform"
    Purpose   = "github-actions-oidc"
  }
}
