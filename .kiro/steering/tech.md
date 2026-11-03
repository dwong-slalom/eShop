# Tech Stack

## Platform

- **.NET 10** (SDK pinned in `global.json`: `10.0.302`, `rollForward: latestFeature`).
- **Aspire** for orchestration, service discovery, and local provisioning.
- C# with `ImplicitUsings` enabled and nullable reference types per project.

## Architecture

- Services-based / microservices layout under `src/`, wired together by the
  Aspire AppHost (`src/eShop.AppHost`).
- Shared cross-cutting defaults live in `src/eShop.ServiceDefaults`
  (telemetry, health checks, resilience, service discovery).
- Asynchronous messaging via an event bus abstraction (`EventBus`) with a
  RabbitMQ implementation (`EventBusRabbitMQ`) and the integration-event log
  (`IntegrationEventLogEF`).
- Data stores and messaging run as containers during local development
  (PostgreSQL, Redis, RabbitMQ).

## Build conventions

- **Central Package Management** — package versions are declared in
  `Directory.Packages.props`. Do not pin versions inside individual `.csproj`
  files; add `<PackageVersion>` entries centrally instead.
- `TreatWarningsAsErrors` is **true** repo-wide (`Directory.Build.props`).
  Code must build clean with no warnings.
- Build output uses the artifacts output layout (`UseArtifactsOutput`).
- Follow `.editorconfig`: 4-space indent for C#, 2-space for project/config XML,
  `System` usings sorted first, final newline on C# files.

## Testing

- Test runner is the **Microsoft Testing Platform** (configured in `global.json`),
  using the **MSTest SDK**.
- Tests live under `tests/`, split into `*.UnitTests` and `*.FunctionalTests`.
- End-to-end browser journeys use **Playwright** (`e2e/`, `playwright.config.ts`).

## Common commands

Run from the repository root.

```bash
# Run the full app via Aspire (requires a running container runtime)
aspire run

# Run in the background
aspire start
aspire ps
aspire stop

# Server tests
dotnet test --solution eShop.Web.slnf

# End-to-end tests (Playwright)
npm ci
npx playwright install chromium
npm run test:e2e
```

> Ensure an OCI-compatible container runtime (Docker Desktop or Podman) is
> running before starting the app or functional/e2e tests.
