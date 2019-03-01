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
docker create --rm --name redis-restore-container -v compose_redis-data:/data topaztechnology/base:3.8
docker start redis-restore-container
docker cp $1/redis.tar.gz redis-restore-container:/tmp
docker exec redis-restore-container sh -c "tar xzvf /tmp/redis.tar.gz -C /data"
docker stop redis-restore-container
docker start compose_redis_1

echo "Removing stale Monet & flatbuffers data"
docker stop compose_monet_1
docker create --rm --name monet-delete-container -v compose_monet-data:/data topaztechnology/base:3.8
docker start monet-delete-container
docker exec monet-delete-container sh -c "rm -rf /data/*"
docker stop monet-delete-container
docker start compose_monet_1
docker create --rm --name topaz-delete-container -v compose_topaz-data:/data topaztechnology/base:3.8
docker start topaz-delete-container
docker exec topaz-delete-container sh -c "rm -rf /data/*"
docker stop topaz-delete-container

echo "Starting Topaz container"
docker start compose_topaz_1
