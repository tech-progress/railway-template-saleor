#!/bin/sh
set -eu

export RSA_PRIVATE_KEY="$(python /template/load-jwt-key.py wait)"
exec "$@"
