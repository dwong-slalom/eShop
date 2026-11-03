# ---------------------------------------------------------------------------
# The 9 eShop .NET services. Images are placeholders until CI pushes real ones
# (the module ignores container_definitions drift, so CI deploys win).
#
# Env vars replicate exactly what the Aspire AppHost injects:
#   - ConnectionStrings__*      from local.conn (Cloud Map internal DNS)
#   - services__<name>__http__0 from local.disco
#   - Identity__Url / IdentityUrl / CallBackUrl / *Client from the ALB hostnames
#   - ASPNETCORE_FORWARDEDHEADERS_ENABLED=true everywhere (behind ALB)
# ---------------------------------------------------------------------------

locals {
  # Real per-service images in ECR, tagged by the build script.
  img = { for name in local.app_services :
    name => "${aws_ecr_repository.svc[name].repository_url}:${var.image_tag}"
  }

  common_env = {
    ASPNETCORE_FORWARDEDHEADERS_ENABLED = "true"
    ASPNETCORE_HTTP_PORTS               = "8080"
    # eShop's ServiceDefaults only maps /health and /alive (and enables data
    # seeding) when the environment is Development. Running the containers in
    # Development keeps health checks working and seeds the catalog/identity
    # data. This is a reference deployment, not production.
    ASPNETCORE_ENVIRONMENT = "Development"
  }
}

# --- identity-api (public) ---
module "identity_api" {
  source       = "./modules/service"
  name         = "identity-api"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["identity-api"]

  env = merge(local.common_env, {
    ConnectionStrings__identitydb = local.conn.identitydb
    # Public URLs of OIDC clients so IdentityServer registers valid redirect URIs.
    WebAppClient      = local.url_webapp
    WebhooksWebClient = local.url_webapp # webhooksclient not public; placeholder
    BasketApiClient   = local.disco["basket-api"]
    OrderingApiClient = local.disco["ordering-api"]
    WebhooksApiClient = local.disco["webhooks-api"]
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  target_group_arn   = aws_lb_target_group.identity.arn
  tags               = var.tags
}

# --- catalog-api (internal, no auth) ---
module "catalog_api" {
  source       = "./modules/service"
  name         = "catalog-api"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["catalog-api"]

  env = merge(local.common_env, {
    ConnectionStrings__catalogdb = local.conn.catalogdb
    ConnectionStrings__eventbus  = local.conn.eventbus
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

# --- basket-api (internal, gRPC/HTTP2) ---
module "basket_api" {
  source       = "./modules/service"
  name         = "basket-api"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["basket-api"]

  env = merge(local.common_env, {
    ConnectionStrings__redis    = local.conn.redis
    ConnectionStrings__eventbus = local.conn.eventbus
    Identity__Url               = local.url_identity
    Identity__Audience          = "basket"
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

# --- ordering-api (internal) ---
module "ordering_api" {
  source       = "./modules/service"
  name         = "ordering-api"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["ordering-api"]

  env = merge(local.common_env, {
    ConnectionStrings__orderingdb = local.conn.orderingdb
    ConnectionStrings__eventbus   = local.conn.eventbus
    Identity__Url                 = local.url_identity
    Identity__Audience            = "orders"
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

# --- order-processor (worker, internal, no inbound port) ---
module "order_processor" {
  source       = "./modules/service"
  name         = "order-processor"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["order-processor"]
  expose_port  = false

  env = merge(local.common_env, {
    ConnectionStrings__orderingdb = local.conn.orderingdb
    ConnectionStrings__eventbus   = local.conn.eventbus
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

# --- payment-processor (worker, internal) ---
module "payment_processor" {
  source       = "./modules/service"
  name         = "payment-processor"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["payment-processor"]
  expose_port  = false

  env = merge(local.common_env, {
    ConnectionStrings__eventbus = local.conn.eventbus
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

# --- webhooks-api (internal) ---
module "webhooks_api" {
  source       = "./modules/service"
  name         = "webhooks-api"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["webhooks-api"]

  env = merge(local.common_env, {
    ConnectionStrings__webhooksdb = local.conn.webhooksdb
    ConnectionStrings__eventbus   = local.conn.eventbus
    Identity__Url                 = local.url_identity
    Identity__Audience            = "webhooks"
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

# --- mobile-bff (public, YARP reverse proxy) ---
# Not a repo project (Aspire generates YARP config at build time). We run the
# official YARP image and supply an equivalent route/cluster config via the
# ReverseProxy__ env namespace. The web storefront does not depend on this; it
# is the mobile BFF, included for topology completeness.
module "mobile_bff" {
  source       = "./modules/service"
  name         = "mobile-bff"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.store_desired_count
  image         = "mcr.microsoft.com/dotnet/nightly/yarp:2.3"

  env = merge(local.common_env, {
    # Clusters -> internal Cloud Map services.
    "REVERSEPROXY__CLUSTERS__catalog__DESTINATIONS__d__ADDRESS"  = local.disco["catalog-api"]
    "REVERSEPROXY__CLUSTERS__ordering__DESTINATIONS__d__ADDRESS" = local.disco["ordering-api"]
    "REVERSEPROXY__CLUSTERS__identity__DESTINATIONS__d__ADDRESS" = local.disco["identity-api"]

    # Catalog: strip /catalog-api prefix, plus a catch-all for /api/catalog.
    "REVERSEPROXY__ROUTES__catalog-prefixed__CLUSTERID"                   = "catalog"
    "REVERSEPROXY__ROUTES__catalog-prefixed__MATCH__PATH"                 = "/catalog-api/{**catch-all}"
    "REVERSEPROXY__ROUTES__catalog-prefixed__TRANSFORMS__0__PathRemovePrefix" = "/catalog-api"
    "REVERSEPROXY__ROUTES__catalog-plain__CLUSTERID"                      = "catalog"
    "REVERSEPROXY__ROUTES__catalog-plain__MATCH__PATH"                    = "/api/catalog/{**catch-all}"

    # Ordering.
    "REVERSEPROXY__ROUTES__orders__CLUSTERID"   = "ordering"
    "REVERSEPROXY__ROUTES__orders__MATCH__PATH" = "/api/orders/{**catch-all}"

    # Identity: strip /identity prefix.
    "REVERSEPROXY__ROUTES__identity__CLUSTERID"                       = "identity"
    "REVERSEPROXY__ROUTES__identity__MATCH__PATH"                     = "/identity/{**catch-all}"
    "REVERSEPROXY__ROUTES__identity__TRANSFORMS__0__PathRemovePrefix" = "/identity"
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  target_group_arn   = aws_lb_target_group.bff.arn
  tags               = var.tags
}

# --- webhooksclient (internal UI) ---
module "webhooksclient" {
  source       = "./modules/service"
  name         = "webhooksclient"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["webhooksclient"]

  env = merge(local.common_env, {
    IdentityUrl                       = local.url_identity
    CallBackUrl                       = local.url_webapp # not publicly routed; placeholder
    "services__webhooks-api__http__0" = local.disco["webhooks-api"]
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  tags               = var.tags
}

# --- webapp (public storefront) ---
module "webapp" {
  source       = "./modules/service"
  name         = "webapp"
  project      = var.project
  region       = var.aws_region
  cluster_arn  = aws_ecs_cluster.eshop.arn
  cluster_name  = aws_ecs_cluster.eshop.name
  desired_count = var.app_desired_count
  image         = local.img["webapp"]

  env = merge(local.common_env, {
    IdentityUrl                       = local.url_identity
    CallBackUrl                       = local.url_webapp
    ConnectionStrings__eventbus       = local.conn.eventbus
    "services__basket-api__http__0"   = local.disco["basket-api"]
    "services__catalog-api__http__0"  = local.disco["catalog-api"]
    "services__ordering-api__http__0" = local.disco["ordering-api"]
  })

  subnets            = aws_subnet.private[*].id
  security_groups    = [aws_security_group.task.id]
  namespace_id       = aws_service_discovery_private_dns_namespace.eshop.id
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn
  log_group          = aws_cloudwatch_log_group.eshop.name
  target_group_arn   = aws_lb_target_group.webapp.arn
  tags               = var.tags
}
