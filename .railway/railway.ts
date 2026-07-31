import {
  bucket,
  defineRailway,
  github,
  group,
  project,
  ref,
  service,
  volume,
} from "railway/iac";

const SOURCE = github("tech-progress/railway-template-saleor", {
  branch: "release-v1",
  rootDirectory: "/",
});

const POSTGRES_IMAGE =
  "postgres:15-alpine@sha256:3d0f7584ed7d04e27fa050d6683a74746608faf21f202be78460d679cc56461f";
const VALKEY_IMAGE =
  "valkey/valkey:8.1-alpine@sha256:a038175878d66b9d274fbf8be73c0305e93798b83917647f167e18cef3c71eec";
const DASHBOARD_IMAGE =
  "ghcr.io/saleor/saleor-dashboard:3.23.20@sha256:c1ce2f625316bf1e02dd8070335bf3bdbaeaa388e14b094d35dd5db2f9b60cf3";

export default defineRailway(() => {
  const databaseData = volume("Saleor PostgreSQL Data", { sizeMB: 5_000 });
  const cacheData = volume("Saleor Valkey Data", { sizeMB: 1_000 });
  const media = bucket("Saleor Media", { region: "iad" });

  const postgres = service("Saleor PostgreSQL", {
    source: { image: POSTGRES_IMAGE },
    volumeMounts: { "/var/lib/postgresql/data": databaseData },
    env: {
      PGDATA: "/var/lib/postgresql/data/pgdata",
      POSTGRES_DB: "saleor",
      POSTGRES_USER: "saleor",
      POSTGRES_PASSWORD: "${{secret(48)}}",
    },
  });

  const cache = service("Saleor Valkey", {
    source: { image: VALKEY_IMAGE },
    start: "valkey-server --appendonly yes",
    volumeMounts: { "/data": cacheData },
  });

  const sharedEnvironment = {
    DATABASE_URL:
      "postgresql://${{Saleor PostgreSQL.POSTGRES_USER}}:${{Saleor PostgreSQL.POSTGRES_PASSWORD}}@${{Saleor PostgreSQL.RAILWAY_PRIVATE_DOMAIN}}:5432/${{Saleor PostgreSQL.POSTGRES_DB}}",
    CACHE_URL: "redis://${{Saleor Valkey.RAILWAY_PRIVATE_DOMAIN}}:6379/0",
    CELERY_BROKER_URL: "redis://${{Saleor Valkey.RAILWAY_PRIVATE_DOMAIN}}:6379/1",
    CELERY_WORKER_CONCURRENCY: "2",
    CELERY_MAX_TASKS_PER_CHILD: "1000",
    SECRET_KEY: "${{secret(64)}}",
    ADMIN_EMAIL: "admin@example.com",
    ADMIN_PASSWORD: "${{secret(32)}}",
    DEBUG: "False",
    SEND_USAGE_TELEMETRY: "False",
    ALLOWED_HOSTS: "*",
    ALLOWED_CLIENT_HOSTS: "*",
    ALLOWED_GRAPHQL_ORIGINS:
      "https://${{Saleor Dashboard.RAILWAY_PUBLIC_DOMAIN}}",
    DASHBOARD_URL: "https://${{Saleor Dashboard.RAILWAY_PUBLIC_DOMAIN}}/",
    PUBLIC_URL: "https://${{Saleor API.RAILWAY_PUBLIC_DOMAIN}}/",
    DEFAULT_FROM_EMAIL: "noreply@example.com",
    EMAIL_URL: "",
    HTTP_IP_FILTER_ENABLED: "True",
    HTTP_IP_FILTER_ALLOW_LOOPBACK_IPS: "True",
    PLAYGROUND_ENABLED: "True",
    TELEMETRY_TRACER_CLASS:
      "saleor.webhook.circuit_breaker.tracer.NoopTelemetryTracer",
    AWS_ACCESS_KEY_ID: ref(media, "ACCESS_KEY_ID"),
    AWS_SECRET_ACCESS_KEY: ref(media, "SECRET_ACCESS_KEY"),
    AWS_MEDIA_BUCKET_NAME: ref(media, "BUCKET"),
    AWS_MEDIA_PRIVATE_BUCKET_NAME: ref(media, "BUCKET"),
    AWS_S3_ENDPOINT_URL: ref(media, "ENDPOINT"),
    AWS_S3_REGION_NAME: ref(media, "REGION"),
    AWS_QUERYSTRING_AUTH: "True",
    AWS_QUERYSTRING_EXPIRE: "3600",
    AWS_AUTO_CREATE_BUCKET: "false",
  };

  const api = service("Saleor API", {
    source: SOURCE,
    build: { builder: "DOCKERFILE", dockerfilePath: "Dockerfile" },
    healthcheck: "/health/",
    healthcheckTimeout: 300,
    env: { PORT: "8000", WEB_CONCURRENCY: "2", ...sharedEnvironment },
  });

  const worker = service("Saleor Worker", {
    source: SOURCE,
    build: { builder: "DOCKERFILE", dockerfilePath: "Dockerfile" },
    start: "/template/start-worker.sh",
    env: {
      ...sharedEnvironment,
      SECRET_KEY: "${{Saleor API.SECRET_KEY}}",
      ADMIN_EMAIL: "${{Saleor API.ADMIN_EMAIL}}",
      ADMIN_PASSWORD: "${{Saleor API.ADMIN_PASSWORD}}",
      DEFAULT_FROM_EMAIL: "${{Saleor API.DEFAULT_FROM_EMAIL}}",
      EMAIL_URL: "${{Saleor API.EMAIL_URL}}",
    },
  });

  const dashboard = service("Saleor Dashboard", {
    source: { image: DASHBOARD_IMAGE },
    healthcheck: "/",
    healthcheckTimeout: 120,
    env: {
      API_URL: "https://${{Saleor API.RAILWAY_PUBLIC_DOMAIN}}/graphql/",
      APP_MOUNT_URI: "/",
    },
  });

  return project("Saleor commerce", {
    resources: [
      group("Application", [dashboard, api, worker]),
      group("Data", [postgres, databaseData, cache, cacheData, media]),
    ],
  });
});
