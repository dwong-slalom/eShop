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

  # App services get their image swapped by CI; ignore to avoid drift.
  lifecycle {
    ignore_changes = [container_definitions]
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
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

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

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}
