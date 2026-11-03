output "role_arn" {
  description = "ARN of the role GitHub Actions assumes. Set this as the role-to-assume in the workflow."
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider used by the trust policy."
  value       = local.oidc_provider_arn
}

output "allowed_subs" {
  description = "The sub claims permitted to assume the role."
  value       = local.allowed_subs
}
