# Publishing

Maintenance baseline checked October 2, 2026: Core `3.23.37` and Dashboard `3.23.38` have independently verified multi-platform digests from `docker buildx imagetools inspect`. PostgreSQL 15 and Valkey 8.1 retain their existing digests rather than silently adopting a different Alpine release or an unvalidated supporting-image patch.

The current template release is `v1.0.1`. Railway application services build from `tech-progress/railway-template-saleor` on `release-v1`; image services use immutable digests.

Run `bun install --frozen-lockfile`, `./scripts/verify.sh`, the empty-volume and initialized-volume smoke tests, and `scripts/check-saleor-standalone.sh` from the monorepo before release. Generate an image-backed draft shell when GitHub App access is unavailable, restore the checked-in serialized defaults, then deploy the queried `serializedConfig` through `templateDeployV2` for verification.

Publish only after every service reports `SUCCESS`, current replicas are running with none crashed, administrator authentication passes, Celery responds, and Saleor's default storage completes a write/read/delete round trip.

```bash
railway templates publish TEMPLATE_ID \
  --category Other \
  --description "Complete Saleor commerce stack with Dashboard, workers, and durable media." \
  --readme-file MARKETPLACE.md \
  --json
```
