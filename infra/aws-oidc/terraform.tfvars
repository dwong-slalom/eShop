# Real values for account 211095244575 (AWS-InnovationLabs-DEN), us-east-1.
# Discovered via aws sts get-caller-identity / describe-vpcs / describe-subnets.

aws_region  = "us-east-1"
github_repo = "dwong-slalom/eShop"

# main branch only.
allowed_git_refs = ["refs/heads/main"]

# The GitHub OIDC provider already exists in this account, so reference it
# instead of creating a duplicate (CreateOpenIDConnectProvider returns 409).
create_oidc_provider = false

role_name = "github-actions-eshop-deploy"

# --- Fargate deploy target ---
# Default VPC vpc-be42e0c3 with three public subnets across us-east-1a/b/c.
vpc_id = "vpc-be42e0c3"
subnet_ids = [
  "subnet-436ff362", # us-east-1a
  "subnet-6165442c", # us-east-1b
  "subnet-f5c250aa", # us-east-1c
]

ecr_repo_name            = "eshop/webapp"
ecs_cluster_name         = "eshop"
ecs_service_name         = "eshop-webapp"
container_name           = "webapp"
task_execution_role_name = "eshop-ecs-task-execution"
task_role_name           = "eshop-ecs-task"

# 0 = service defined but not running, so no Fargate charges accrue.
# Scale up when ready:
#   aws ecs update-service --cluster eshop --service eshop-webapp --desired-count 1
desired_count = 0
