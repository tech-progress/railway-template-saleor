# Deploy and Host Saleor Commerce on Railway

Deploy Saleor Core and Dashboard with a background worker, PostgreSQL, Valkey, and durable S3-compatible media storage. The template keeps data services private, generates installation secrets, applies database migrations, and creates the first administrator.

## About Hosting Saleor Commerce

Saleor is a headless commerce platform built around a GraphQL API. This topology separates the browser Dashboard, API, and Celery worker while sharing PostgreSQL, Valkey, and object storage through Railway-managed resources.

## Why Deploy Saleor Commerce on Railway

Railway provides managed networking, TLS domains, persistent database volumes, and a private Bucket without relying on the shared local media volume used by Saleor's development-only Compose stack. Both API and worker read the same durable object storage.

## Common Use Cases

- Build a headless storefront against Saleor's GraphQL API.
- Operate an internal product, order, and channel administration backend.
- Evaluate Saleor extensions and webhooks with persistent data.
- Run a small commerce service before designing a high-availability topology.

## Dependencies for Saleor Commerce

Configure SMTP through `EMAIL_URL` before enabling customer email flows. A storefront, payment applications, tax integrations, and observability are separate product decisions and are not bundled.

### Deployment Dependencies

- Saleor Core `3.23.23`
- Saleor Dashboard `3.23.20`
- PostgreSQL 15 with a persistent volume
- Valkey 8.1 with a persistent volume
- A private Railway Bucket for public and private media objects

