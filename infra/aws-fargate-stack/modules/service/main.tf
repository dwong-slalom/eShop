locals {
  use_efs = var.efs_file_system_id != null

  container = merge(
    {
      name      = var.name
      image     = var.image
      essential = true
      environment = [
        for k, v in var.env : { name = k, value = v }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = var.name
        }
      }
    },
    var.expose_port ? {
      portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
    } : {},
    var.command != null ? { command = var.command } : {},
    var.entrypoint != null ? { entryPoint = var.entrypoint } : {},
    var.health_check != null ? { healthCheck = var.health_check } : {},
    local.use_efs ? {
      mountPoints = [{
        sourceVolume  = "data"
        containerPath = var.mount_path
        readOnly      = false
      }]
    } : {},
  )
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project}-${var.name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  # Images are built for linux-arm64 (matches the arm64 build host and runs on
  # Graviton Fargate). The public store/proxy images are multi-arch, so ARM64
  # works for them too.
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([local.container])

  dynamic "volume" {
    for_each = local.use_efs ? [1] : []
    content {
      name = "data"
      efs_volume_configuration {
        file_system_id     = var.efs_file_system_id
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = var.efs_access_point_id
          iam             = "DISABLED"
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_service_discovery_service" "this" {
  name = var.name
  dns_config {
    namespace_id = var.namespace_id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name                              = var.name
  cluster                           = var.cluster_arn
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = var.target_group_arn != null ? var.health_check_grace_period_seconds : null

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  tags = var.tags
}
