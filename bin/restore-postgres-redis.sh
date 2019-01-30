#!/bin/bash

# Usage: restore-postgres-redis.sh <FULL PATH>
set -eo pipefail

echo "Stopping Topaz container"
docker stop compose_topaz_1

echo "Restoring Postgres backup"
docker cp $1/postgres.sql.gz compose_postgres_1:/tmp
docker exec compose_postgres_1 sh -c "psql -U topaz topaz-main -c 'DROP TABLE public.journal; DROP TABLE public.snapshot;' && gunzip -c /tmp/postgres.sql.gz | psql -U topaz topaz-main && rm /tmp/postgres.sql.gz"

echo "Restoring Redis backup"
docker exec compose_redis_1 sh -c "redis-cli save"
docker stop compose_redis_1
docker create --rm --name redis-restore-container -v compose_redis-data:/restore topaztechnology/base:3.6
docker start redis-restore-container
docker cp $1/redis.tar.gz redis-restore-container:/tmp
docker exec redis-restore-container sh -c "tar zxvf /tmp/redis.tar.gz -C /restore"
docker stop redis-restore-container
docker start compose_redis_1

echo "Starting Topaz container"
docker start compose_topaz_1
