# Publishing

The current template release is `v1.0.0`. Railway application services build from `tech-progress/railway-template-saleor` on `release-v1`; image services use immutable digests.

Run `bun install --frozen-lockfile`, `./scripts/verify.sh`, the empty-volume and initialized-volume smoke tests, and `scripts/check-saleor-standalone.sh` from the monorepo before release. Generate an image-backed draft shell when GitHub App access is unavailable, restore the checked-in serialized defaults, then deploy the queried `serializedConfig` through `templateDeployV2` for verification.

Publish only after every service reports `SUCCESS`, current replicas are running with none crashed, administrator authentication passes, Celery responds, and Saleor's default storage completes a write/read/delete round trip.

```bash
railway templates publish TEMPLATE_ID \
  --category Other \
  --description "Saleor commerce with Dashboard, worker, PostgreSQL, Valkey, and durable media." \
  --readme-file MARKETPLACE.md \
  --json
```
