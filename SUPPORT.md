# Support boundary

This template supports one API service, one combined Celery worker/Beat service, one Dashboard, PostgreSQL, Valkey, and one private Railway Bucket. It targets evaluation, internal commerce tools, and small stores that accept single-region maintenance windows.

It does not provide Saleor Cloud support, a storefront, horizontal worker scheduling, PostgreSQL replicas, tracing, SMTP, CDN behavior, or high availability. Railway Buckets do not currently provide versioning or automatic backups, so export media separately and coordinate it with PostgreSQL backups.

The generated administrator password is applied only when the account is first created. Changing the Railway variable later does not rotate the existing password; use Saleor's account tools for rotation.
