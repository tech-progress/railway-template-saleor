# Saleor commerce Railway template

The current template release is `v1.0.0`. It deploys Saleor Core `3.23.23`, Dashboard `3.23.20`, a Celery worker with Beat, PostgreSQL 15, Valkey 8.1, and a private Railway Bucket for shared media. All runtime images are pinned by digest.

## Deploy on Railway

Set `ADMIN_EMAIL` if the default is unsuitable; Railway generates `ADMIN_PASSWORD`, `SECRET_KEY`, and the database password. The API creates the first administrator without resetting an existing password, applies migrations on startup, and exposes `/graphql/`. Open the Dashboard domain and sign in with those administrator values.

`EMAIL_URL` is optional and blank by default, so transactional email is disabled until you provide a `dj-email-url` SMTP URL such as `smtp://user:password@host:587/?tls=True`. Configure email before using password reset or order notifications.

The bucket stays private. Saleor generates signed media URLs and both the API and worker use the same object store, avoiding the unsupported shared-volume pattern from the development Compose stack. The template also stores Saleor's generated JWT signing key in a private bucket object so API and worker tokens remain valid across restarts; include that object in bucket backups.

## Services and persistence

- Saleor Dashboard is public on port 80.
- Saleor API is public on port 8000 and keeps GraphQL playground enabled for setup and evaluation.
- Saleor Worker is private and runs Celery worker plus Beat in one singleton process.
- PostgreSQL and Valkey are private, with 5 GB and 1 GB persistent volumes.
- Saleor Media is a private S3-compatible Railway Bucket shared by the API and worker.

Back up PostgreSQL and the bucket together before upgrades. Valkey holds cache and broker state; losing it can discard queued tasks, but PostgreSQL and object storage remain authoritative.

The worker starts with `CELERY_WORKER_CONCURRENCY=2` and recycles children after 1,000 tasks. Raise concurrency only after increasing worker memory, and keep the combined worker/Beat service at one replica so scheduled jobs aren't duplicated.

## Local verification

Copy `.env.example` to `.env`, replace every placeholder, then run:

```bash
docker compose up --build -d
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD='<password>' ./scripts/smoke.sh
docker compose exec api /template/with-jwt-key.sh python /template/storage-smoke.py
docker compose exec api /template/with-jwt-key.sh celery -A saleor --app=saleor.celeryconf:app inspect ping --timeout 10
```

The local MinIO service exists only to exercise Saleor's S3 storage path; Railway uses a native Bucket instead.

## Support boundary

This is a small-team, single-region baseline, not Saleor Cloud or a high-availability deployment. It omits Jaeger, Mailpit, a storefront, database replicas, and separate Beat scheduling. Review [SUPPORT.md](SUPPORT.md) before production use and [UPGRADE.md](UPGRADE.md) before changing image pins.
