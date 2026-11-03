locals {
  # Public hostnames (DNS names we assign, so they're known before apply —
  # this is what lets us resolve the OIDC circular-URL problem up front).
  host_webapp   = "${var.subdomain_webapp}.${var.domain}"
  host_identity = "${var.subdomain_identity}.${var.domain}"
  host_bff      = "${var.subdomain_bff}.${var.domain}"

  url_webapp   = "https://${local.host_webapp}"
  url_identity = "https://${local.host_identity}"
  url_bff      = "https://${local.host_bff}"

  # Cloud Map private DNS namespace: every service is <name>.eshop.local
  namespace = "${var.project}.local"

  svc = {
    for name in [
      "identity-api", "basket-api", "catalog-api", "ordering-api",
      "order-processor", "payment-processor", "webhooks-api",
      "mobile-bff", "webhooksclient", "webapp",
      "postgres", "redis", "eventbus",
    ] : name => "${name}.${local.namespace}"
  }

  # Internal connection strings built from Cloud Map DNS.
  pg_host = local.svc["postgres"]
  conn = {
    catalogdb  = "Host=${local.pg_host};Port=5432;Username=${var.postgres_user};Password=${var.postgres_password};Database=catalogdb"
    identitydb = "Host=${local.pg_host};Port=5432;Username=${var.postgres_user};Password=${var.postgres_password};Database=identitydb"
    orderingdb = "Host=${local.pg_host};Port=5432;Username=${var.postgres_user};Password=${var.postgres_password};Database=orderingdb"
    webhooksdb = "Host=${local.pg_host};Port=5432;Username=${var.postgres_user};Password=${var.postgres_password};Database=webhooksdb"
    redis      = "${local.svc["redis"]}:6379"
    eventbus   = "amqp://${var.rabbitmq_user}:${var.rabbitmq_password}@${local.svc["eventbus"]}:5672"
  }

  # Service-discovery URLs (internal h2c/http on 8080).
  disco = {
    "identity-api" = "http://${local.svc["identity-api"]}:8080"
    "basket-api"   = "http://${local.svc["basket-api"]}:8080"
    "catalog-api"  = "http://${local.svc["catalog-api"]}:8080"
    "ordering-api" = "http://${local.svc["ordering-api"]}:8080"
    "webhooks-api" = "http://${local.svc["webhooks-api"]}:8080"
  }
}
