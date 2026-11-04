# Distinct project prefix so this full-stack deployment does not collide with
# the earlier single-service aws-oidc stack, which already owns the "eshop"
# ECS cluster, the eshop/webapp ECR repo, and the eshop-task* IAM roles.
# Public hostnames are controlled by the subdomain_*/domain variables, not by
# this prefix, so the storefront URL stays https://eshop.<domain>.
project = "eshopf"

# Bring the backing stores up on the first apply; app services stay at 0 until
# their images are built and pushed, then we raise this to 1 and re-apply.
# Running: backing stores and app services are both up.
# (To pause the stack, set both to 0 and apply. Infra and images are preserved.)
store_desired_count = 1
app_desired_count   = 1
image_tag           = "2466233"

# Lock the public ALB down to this workstation's public IP only.
allowed_ingress_cidrs = ["72.10.71.58/32"]
