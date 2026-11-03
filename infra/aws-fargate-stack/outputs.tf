output "cluster_name" {
  value = aws_ecs_cluster.eshop.name
}

output "alb_dns_name" {
  value = aws_lb.public.dns_name
}

output "urls" {
  value = {
    webapp   = local.url_webapp
    identity = local.url_identity
    bff      = local.url_bff
  }
}

output "ecr_repository_urls" {
  value = { for k, r in aws_ecr_repository.svc : k => r.repository_url }
}

output "app_services" {
  description = "App service names (for the deploy pipeline matrix)."
  value       = local.app_services
}
