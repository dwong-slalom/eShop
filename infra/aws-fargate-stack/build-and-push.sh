#!/usr/bin/env bash
# Build and push all 9 eShop app-service images as linux-arm64 to the
# eshopf/<service> ECR repos. Mirrors what the Aspire/.NET SDK container
# publish does, matching the ARM64 Fargate runtime platform.
set -uo pipefail

REGION=us-east-1
REGISTRY=211095244575.dkr.ecr.us-east-1.amazonaws.com
TAG=$(git rev-parse --short HEAD)
echo "=== Image tag: $TAG ==="

# ECR login (Podman).
aws ecr get-login-password --region "$REGION" \
  | podman login --username AWS --password-stdin "$REGISTRY" || exit 1

# repo-name -> project path
declare -a SERVICES=(
  "identity-api:src/Identity.API/Identity.API.csproj"
  "basket-api:src/Basket.API/Basket.API.csproj"
  "catalog-api:src/Catalog.API/Catalog.API.csproj"
  "ordering-api:src/Ordering.API/Ordering.API.csproj"
  "order-processor:src/OrderProcessor/OrderProcessor.csproj"
  "payment-processor:src/PaymentProcessor/PaymentProcessor.csproj"
  "webhooks-api:src/Webhooks.API/Webhooks.API.csproj"
  "webhooksclient:src/WebhookClient/WebhookClient.csproj"
  "webapp:src/WebApp/WebApp.csproj"
)

FAILED=()
for entry in "${SERVICES[@]}"; do
  repo="${entry%%:*}"
  proj="${entry#*:}"
  echo ""
  echo "=== Building $repo from $proj ==="
  DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet publish "$proj" \
    -c Release \
    /t:PublishContainer \
    -p:ContainerRegistry="$REGISTRY" \
    -p:ContainerRepository="eshopf/$repo" \
    -p:ContainerImageTag="$TAG" \
    -p:ContainerPort=8080 \
    -p:ContainerRuntimeIdentifier=linux-arm64 \
    -p:RuntimeIdentifier=linux-arm64 \
    2>&1 | tail -3
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo "!!! FAILED: $repo"
    FAILED+=("$repo")
  else
    echo "+++ OK: eshopf/$repo:$TAG"
  fi
done

echo ""
echo "=== DONE. Tag=$TAG ==="
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "FAILED services: ${FAILED[*]}"
  exit 1
fi
echo "All 9 images pushed."
