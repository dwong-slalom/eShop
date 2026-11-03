terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # One sub claim per allowed ref. Scoped to the main branch by default.
  # Examples you could add instead/as well:
  #   "repo:dwong-slalom/eShop:environment:production"
  #   "repo:dwong-slalom/eShop:ref:refs/tags/v*"
  allowed_subs = [
    for ref in var.allowed_git_refs :
    "repo:${var.github_repo}:ref:${ref}"
  ]
}

#######################################
# GitHub OIDC identity provider
#######################################
# One provider per AWS account. If token.actions.githubusercontent.com is
# already registered in this account, import it instead of creating a duplicate:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS no longer verifies this thumbprint for the GitHub OIDC endpoint (it uses
  # the library of trusted CAs), but the argument is still required by the API.
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]

  tags = var.tags
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

#######################################
# Role assumed by GitHub Actions
#######################################
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subs
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = var.role_name
  description          = "Assumed by GitHub Actions (${var.github_repo}) via OIDC to deploy eShop to ECS Fargate."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600

  tags = var.tags
}

#######################################
# Deploy permissions: ECR push + ECS Fargate deploy
#######################################
data "aws_iam_policy_document" "deploy" {
  # --- ECR: authenticate to the registry ---
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken does not support resource-level scoping
  }

  # --- ECR: push/pull images for the eShop repositories ---
  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.webapp.arn]
  }

  # --- ECS: register new task definitions and roll the service ---
  statement {
    sid    = "EcsRegister"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
    ]
    # These three do not support resource-level permissions in IAM.
    resources = ["*"]
  }

  statement {
    sid    = "EcsServiceDeploy"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [aws_ecs_service.webapp.id]
  }

  statement {
    sid    = "EcsTasksRead"
    effect = "Allow"
    actions = [
      "ecs:DescribeTasks",
      "ecs:ListTasks",
    ]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.eshop.arn]
    }
  }

  # --- IAM: pass the task execution/task roles to ECS during deployment ---
  statement {
    sid     = "PassEcsRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.task_execution.arn,
      aws_iam_role.task.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.role_name}-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deploy.json
}
