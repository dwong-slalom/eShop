# ---------------------------------------------------------------------------
# Backing stores as internal Fargate services (reachable via Cloud Map).
# Public container images, so no ECR build needed for these.
# ---------------------------------------------------------------------------

module "postgres" {
  source       = "./modules/service"
  name         = "postgres"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name = aws_ecs_cluster.eshop.name

  image  = "pgvector/pgvector:pg16"
  cpu    = 512
  memory = 1024

  env = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = "postgres"
    PGDATA            = "/var/lib/postgresql/data/pgdata"
  }

  container_port      = 5432
  subnets             = aws_subnet.private[*].id
  security_groups     = [aws_security_group.task.id]
  namespace_id        = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn  = aws_iam_role.task_execution.arn
  task_role_arn       = aws_iam_role.task.arn
  log_group           = aws_cloudwatch_log_group.eshop.name
  efs_file_system_id  = aws_efs_file_system.postgres.id
  efs_access_point_id = aws_efs_access_point.postgres.id
  mount_path          = "/var/lib/postgresql/data"
  tags                = var.tags
}

module "redis" {
  source       = "./modules/service"
  name         = "redis"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name = aws_ecs_cluster.eshop.name

  image          = "redis:7.4"
  container_port = 6379

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

module "eventbus" {
  source       = "./modules/service"
  name         = "eventbus"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name = aws_ecs_cluster.eshop.name

  image          = "rabbitmq:3.13-management"
  cpu            = 512
  memory         = 1024
  container_port = 5672

  env = {
    RABBITMQ_DEFAULT_USER = var.rabbitmq_user
    RABBITMQ_DEFAULT_PASS = var.rabbitmq_password
  }

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}
