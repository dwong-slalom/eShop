variable "name" { type = string }
variable "cluster_arn" { type = string }
variable "cluster_name" { type = string }
variable "region" { type = string }
variable "project" { type = string }

variable "image" {
  type        = string
  description = "Container image URI. For bootstrap, a placeholder public image."
}

variable "cpu" {
  type    = number
  default = 256
}
variable "memory" {
  type    = number
  default = 512
}

variable "env" {
  type        = map(string)
  description = "Environment variables for the container."
  default     = {}
}

variable "command" {
  type        = list(string)
  description = "Optional container command override."
  default     = null
}

variable "entrypoint" {
  type        = list(string)
  description = "Optional container entryPoint override."
  default     = null
}

variable "health_check" {
  type        = any
  description = "Optional ECS container-level healthCheck block."
  default     = null
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "expose_port" {
  type        = bool
  description = "Whether the container publishes a port + registers an SRV/A record."
  default     = true
}

variable "desired_count" {
  type    = number
  default = 0
}

variable "subnets" { type = list(string) }
variable "security_groups" { type = list(string) }
variable "namespace_id" { type = string }
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "log_group" { type = string }

# Optional ALB target group to attach (for the 3 public services).
variable "target_group_arn" {
  type    = string
  default = null
}

# Optional EFS volume (for postgres).
variable "efs_file_system_id" {
  type    = string
  default = null
}
variable "efs_access_point_id" {
  type    = string
  default = null
}
variable "mount_path" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
