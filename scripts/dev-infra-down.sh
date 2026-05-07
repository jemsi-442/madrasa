#!/usr/bin/env bash
set -euo pipefail

REDIS_CONTAINER="mms-redis"

stop_if_exists() {
  local container_name="$1"
  if docker container inspect "$container_name" >/dev/null 2>&1; then
    docker stop "$container_name" >/dev/null || true
  fi
}

stop_if_exists "$REDIS_CONTAINER"

echo "MMS dev infrastructure stopped"
docker ps -a --filter "name=$REDIS_CONTAINER"
