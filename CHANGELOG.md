# Changelog

## [1.0.1] - 2026-10-02

- Refresh Saleor Core to 3.23.37 and the independently released Dashboard to 3.23.38 with separate registry-verified immutable digests.
- Retain existing PostgreSQL 15 and Valkey 8.1 image digests, environment variables, and storage/bootstrap behavior.

## [1.0.0] - 2026-07-31

- Add Saleor API, worker, dashboard, PostgreSQL, Valkey, and Railway Bucket topology.
- Add idempotent migrations, administrator bootstrap, and local/remote smoke tooling.
