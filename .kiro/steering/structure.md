# Project Structure

## Top level

- `src/` — application services and shared libraries.
- `tests/` — unit and functional test projects.
- `e2e/` — Playwright end-to-end browser journeys.
- `eShop.slnx` — the full solution; `eShop.Web.slnf` — web-focused solution filter.
- `aspire.config.json` — selects the AppHost project for `aspire run`.
- `Directory.Build.props` / `Directory.Build.targets` — shared MSBuild settings.
- `Directory.Packages.props` — central NuGet package versions.
- `global.json` — SDK and test-runner pinning.

## Services and libraries (`src/`)

### Orchestration & shared
- `eShop.AppHost` — Aspire app model; the entry point for `aspire run`.
- `eShop.ServiceDefaults` — shared telemetry, health, resilience, discovery.
- `Shared` — common types shared across services.

### Backend services (APIs)
- `Catalog.API` — product catalog.
- `Basket.API` — shopping basket.
- `Ordering.API` — order placement and management.
- `Identity.API` — authentication and identity.
- `Webhooks.API` — webhook subscriptions and dispatch.

### Ordering domain (DDD layering)
- `Ordering.Domain` — domain model and business rules.
- `Ordering.Infrastructure` — persistence and infrastructure for ordering.

### Messaging & background processing
- `EventBus` — event bus abstraction.
- `EventBusRabbitMQ` — RabbitMQ implementation.
- `IntegrationEventLogEF` — integration event log (outbox-style) with EF.
- `OrderProcessor` — background order processing.
- `PaymentProcessor` — background payment processing.

### Front-end & clients
- `WebApp` — Blazor storefront.
- `WebAppComponents` — shared UI components.
- `ClientApp` / `HybridApp` — companion client applications.
- `WebhookClient` — sample webhook consumer.

## Tests (`tests/`)

Mirror the services they cover:
- `*.UnitTests` — isolated unit tests (e.g. `Ordering.UnitTests`,
  `Basket.UnitTests`, `Catalog.*`, `Application.UnitTests`, `ClientApp.UnitTests`,
  `eShop.AppHost.UnitTests`).
- `*.FunctionalTests` — service-level functional tests
  (e.g. `Catalog.FunctionalTests`, `Basket.FunctionalTests`,
  `Ordering.FunctionalTests`, `Webhooks.FunctionalTests`).

## Conventions

- Keep a service's concerns within its own project; share only through
  `Shared`, `ServiceDefaults`, or the event bus.
- Register new services in the Aspire AppHost so they participate in
  orchestration, discovery, and telemetry.
- Add a matching test project under `tests/` when introducing a new service.
- Respect the domain/infrastructure split for the Ordering area.
