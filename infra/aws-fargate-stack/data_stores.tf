# ---------------------------------------------------------------------------
# Backing stores as internal Fargate services (reachable via Cloud Map).
# Public container images, so no ECR build needed for these.
# ---------------------------------------------------------------------------

module "postgres" {
  source       = "./modules/service"
  name          = "postgres"
  project       = var.project
  region        = var.aws_region
  cluster_arn   = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.store_desired_count

  image  = "pgvector/pgvector:pg16"
  cpu    = 512
  memory = 1024

  env = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB = "postgres"
    # Fresh data subdirectory. The original /pgdata cluster was initialised on
    # x86_64 before the stack moved to ARM64 Fargate; PostgreSQL data dirs are
    # not portable across architectures (WAL/checkpoint PANIC on recovery), so
    # we initialise a clean aarch64 cluster here.
    PGDATA = "/var/lib/postgresql/data/pgdata-arm64"
  }

  # eShop needs four databases (catalogdb, identitydb, orderingdb, webhooksdb).
  # The stock image only creates POSTGRES_DB. We drop an idempotent init script
  # into /docker-entrypoint-initdb.d before handing off to the normal entrypoint
  # (runs on a fresh volume), and also kick off a background psql loop that
  # creates them if the volume was already initialised on a prior run.
  entrypoint = [
    "/bin/bash", "-c",
    <<-EOT
      set -e
      cat > /docker-entrypoint-initdb.d/00-eshop-dbs.sql <<'SQL'
      SELECT 'CREATE DATABASE catalogdb'  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'catalogdb')\gexec
      SELECT 'CREATE DATABASE identitydb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'identitydb')\gexec
      SELECT 'CREATE DATABASE orderingdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'orderingdb')\gexec
      SELECT 'CREATE DATABASE webhooksdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'webhooksdb')\gexec
      SQL
      (
        export PGPASSWORD="$POSTGRES_PASSWORD"
        until pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do sleep 2; done
        for db in catalogdb identitydb orderingdb webhooksdb; do
          psql -v ON_ERROR_STOP=0 -U "$POSTGRES_USER" -d postgres -tc \
            "SELECT 1 FROM pg_database WHERE datname='$db'" | grep -q 1 \
            || psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $db"
        done
      ) &
      exec docker-entrypoint.sh postgres
    EOT
  ]

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
  name          = "redis"
  project       = var.project
  region        = var.aws_region
  cluster_arn   = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.store_desired_count

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
  name          = "eventbus"
  project       = var.project
  region        = var.aws_region
  cluster_arn   = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.store_desired_count

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
