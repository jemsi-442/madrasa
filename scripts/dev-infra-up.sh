#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REDIS_CONTAINER="mms-redis"
REDIS_VOLUME="redis_data"

ensure_volume() {
  local volume_name="$1"
  if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
    docker volume create "$volume_name" >/dev/null
  fi
}

start_or_create_redis() {
  if docker container inspect "$REDIS_CONTAINER" >/dev/null 2>&1; then
    docker rm -f "$REDIS_CONTAINER" >/dev/null
  fi

  docker run -d \
    --name "$REDIS_CONTAINER" \
    --restart unless-stopped \
    -p 6379:6379 \
    -v "$REDIS_VOLUME":/data \
    redis:7.4-alpine \
    redis-server --appendonly yes >/dev/null
}

ensure_volume "$REDIS_VOLUME"
start_or_create_redis

echo "MMS dev infrastructure started"
echo "MariaDB is expected on the host at 127.0.0.1:3306"
docker ps --filter "name=$REDIS_CONTAINER"
