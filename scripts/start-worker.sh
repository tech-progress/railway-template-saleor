#!/bin/sh
set -eu

python /template/load-jwt-key.py wait >/dev/null

until /template/with-jwt-key.sh python manage.py migrate --check >/dev/null 2>&1; do
  echo "Waiting for Saleor database migrations."
  sleep 2
done

exec /template/with-jwt-key.sh celery -A saleor --app=saleor.celeryconf:app worker \
  --loglevel=info -B --concurrency="${CELERY_WORKER_CONCURRENCY:-2}" \
  --max-tasks-per-child="${CELERY_MAX_TASKS_PER_CHILD:-1000}"
