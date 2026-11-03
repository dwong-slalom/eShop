#######################################
# ECS Fargate stack for eShop
#
# This provisions the deploy TARGET so the GitHub Actions role in main.tf has
# real resources to deploy to. desired_count defaults to 0 so nothing runs
# (and nothing bills) until you scale it up:
#   aws ecs update-service --cluster eshop --service eshop-webapp --desired-count 1
#######################################

data "aws_vpc" "selected" {
  id = var.vpc_id
}

#######################################
# ECR repository
# Created out-of-band via the AWS CLI, imported here so Terraform manages it.
# If you prefer TF to own creation from scratch, remove the import block and run apply.
#######################################
resource "aws_ecr_repository" "webapp" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

import {
  to = aws_ecr_repository.webapp
  id = var.ecr_repo_name
}

#######################################
# CloudWatch log group for task logs
#######################################
resource "aws_cloudwatch_log_group" "webapp" {
  name              = "/ecs/${var.ecs_service_name}"
  retention_in_days = 14
  tags              = var.tags
}

#######################################
# ECS cluster
#######################################
resource "aws_ecs_cluster" "eshop" {
  name = var.ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "eshop" {
  cluster_name       = aws_ecs_cluster.eshop.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

#######################################
# Task roles
#######################################
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: used by the ECS agent to pull images and write logs.
resource "aws_iam_role" "task_execution" {
  name               = var.task_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: assumed by the application container itself (app-level AWS calls).
resource "aws_iam_role" "task" {
  name               = var.task_role_name
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

#######################################
# Security group for the service
#######################################
resource "aws_security_group" "service" {
  name        = "${var.ecs_service_name}-sg"
  description = "eShop Fargate service"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

#######################################
# Task definition
# A placeholder container; the deploy workflow replaces the image on each run
# via amazon-ecs-render-task-definition.
#######################################
resource "aws_ecs_task_definition" "webapp" {
  family                   = var.ecs_service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = "${aws_ecr_repository.webapp.repository_url}:bootstrap"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.webapp.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags

  # The workflow registers new revisions with updated images; ignore drift here.
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

#######################################
# ECS service (desired_count 0 by default = not running, not billing)
#######################################
resource "aws_ecs_service" "webapp" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.eshop.id
  task_definition = aws_ecs_task_definition.webapp.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  # The GitHub Actions deploy updates the running task def out-of-band.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}
