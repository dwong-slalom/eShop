resource "aws_ecs_cluster" "eshop" {
  name = var.project
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

# --- IAM roles shared by all tasks ---
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

resource "aws_iam_role" "task_execution" {
  name               = "${var.project}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.project}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

# --- ECR repositories, one per app service (9 .NET services) ---
locals {
  app_services = [
    "identity-api", "basket-api", "catalog-api", "ordering-api",
    "order-processor", "payment-processor", "webhooks-api",
    "webhooksclient", "webapp",
  ]
}

resource "aws_ecr_repository" "svc" {
  for_each             = toset(local.app_services)
  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = var.tags
}
