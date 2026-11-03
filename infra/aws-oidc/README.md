# GitHub Actions → AWS OIDC + ECS Fargate (keyless CI/CD)

Terraform that lets GitHub Actions in `dwong-slalom/eShop` authenticate to AWS
via OIDC — no long-lived access keys — and deploy the eShop container to
**ECS Fargate**. It also provisions the deploy target (cluster, service, task
definition, roles) so the pipeline has somewhere real to deploy.

Target account: **211095244575** (AWS-InnovationLabs-DEN), region **us-east-1**.

## What it creates

OIDC / CI identity (`main.tf`):
- IAM OIDC identity provider for `token.actions.githubusercontent.com`.
- IAM role `github-actions-eshop-deploy`, trust scoped to `refs/heads/main` of
  the repo via the OIDC `sub` claim.
- Inline least-privilege deploy policy: ECR auth+push, ECS register/update,
  `iam:PassRole` for the two task roles.

Fargate deploy target (`fargate.tf`):
- ECR repo `eshop/webapp` (created via CLI, imported into TF state).
- ECS cluster `eshop` (FARGATE capacity provider).
- Task execution role `eshop-ecs-task-execution` + task role `eshop-ecs-task`.
- Security group, CloudWatch log group `/ecs/eshop-webapp`.
- Task definition `eshop-webapp` (placeholder image; the workflow swaps it).
- ECS service `eshop-webapp` with **`desired_count = 0`**.

## Cost safety

`desired_count = 0` means the service is **defined but not running**, so no
Fargate vCPU/GB charges accrue. ECR storage and CloudWatch logs are negligible.
Scale up only when you're ready to pay for a running task:

```bash
aws ecs update-service --cluster eshop --service eshop-webapp --desired-count 1
```

Tear everything down with `terraform destroy`.

## Prerequisites

- Terraform >= 1.5, AWS provider >= 5.0.
- AWS creds for account 211095244575 (`aws sts get-caller-identity` to confirm).

## Usage

```bash
cd infra/aws-oidc
terraform init
terraform plan     # includes an import of the existing eshop/webapp ECR repo
terraform apply
```

The ECR repo is brought under management via an `import` block in `fargate.tf`,
so the first `plan`/`apply` imports rather than recreates it.

After apply, wire the role into CI:

```bash
terraform output role_arn
# set it as the GitHub repo variable AWS_DEPLOY_ROLE_ARN (used by
# .github/workflows/deploy-fargate.yml)
```

## Scope / security notes

- Role assumable **only** from `refs/heads/main` of `dwong-slalom/eShop`.
- ECR push scoped to the `eshop/webapp` repo ARN; ECS service actions scoped to
  the service ARN; task reads scoped by `ecs:cluster` condition.
- `ecr:GetAuthorizationToken` and `ecs:Register/DescribeTaskDefinition` use
  `resources = ["*"]` because AWS does not support resource-level scoping on them.
- `iam:PassRole` constrained to `ecs-tasks.amazonaws.com` and the two task role ARNs.
