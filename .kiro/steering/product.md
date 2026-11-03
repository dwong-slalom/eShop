# Product

eShop ("AdventureWorks") is a reference .NET application that implements an
e-commerce website using a services-based architecture orchestrated with
[Aspire](https://aspire.dev/). It is a learning and demonstration sample for
building cloud-native .NET applications, not a production storefront.

## What it does

- Lets customers browse a product catalog, manage a shopping basket, and place
  orders through a web storefront and companion client apps.
- Demonstrates a distributed system composed of independent services that
  communicate over HTTP and an asynchronous event bus.
- Showcases cross-cutting concerns: identity/authentication, resilience,
  observability (OpenTelemetry), and integration event handling.
- Optionally integrates an AI chatbot backed by Microsoft Foundry.

## Primary user-facing surfaces

- `WebApp` — the Blazor storefront.
- `HybridApp` / `ClientApp` — companion client applications.
- `Identity.API` — authentication and user identity.

## Audience

Developers evaluating or learning cloud-native .NET and Aspire patterns.
Treat demonstration shortcuts (containers for data stores, sample seed data)
as evaluation conveniences rather than production guidance.
