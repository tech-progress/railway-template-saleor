#!/bin/sh
set -eu

python /template/load-jwt-key.py create >/dev/null
/template/with-jwt-key.sh python /template/bootstrap.py
exec /template/with-jwt-key.sh uvicorn saleor.asgi:application \
  --host=0.0.0.0 --port="${PORT:-8000}" --workers="${WEB_CONCURRENCY:-2}" \
  --lifespan=auto --ws=none --no-server-header --no-access-log \
  --timeout-keep-alive=35 --timeout-graceful-shutdown=30 --limit-max-requests=10000
