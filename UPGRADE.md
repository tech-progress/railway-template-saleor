# Upgrade procedure

Back up PostgreSQL and export the Railway Bucket before changing Saleor. Read both Core and Dashboard release notes, update their versions and immutable digests independently, then verify migrations on a restored copy of production data.

Deploy the API first so its idempotent bootstrap applies migrations, then confirm `/health/`, GraphQL administrator login, Dashboard loading, a Celery ping, and the object-storage write/read/delete test. Roll back application images only when the release notes say the migrated schema remains backward compatible; otherwise restore the coordinated database and bucket backup.

PostgreSQL major upgrades require dump/restore rather than swapping the image tag against the existing data directory. Valkey can be recreated after draining tasks, but expect cache loss and verify no jobs remain queued first.
