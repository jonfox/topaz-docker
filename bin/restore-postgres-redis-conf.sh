#!/bin/bash

# Usage: restore-postgres-redis.sh <FULL PATH> [DOCKER PROJECT]

set -eo pipefail

BACKUP_PATH=$1

if [ -z "$2" ]; then
  DOCKER_PROJECT=$(basename `pwd`)
else
  DOCKER_PROJECT=$2
fi

echo "Stopping Topaz container"
docker stop ${DOCKER_PROJECT}_topaz_1

echo "Restoring conf backup"
docker create --rm --name conf-restore-container -v topaz-conf:/conf topaztechnology/base:3.11.3
docker start conf-restore-container
docker cp ${BACKUP_PATH}/conf.tar.gz conf-restore-container:/tmp
docker exec conf-restore-container sh -c "tar zxvf /tmp/conf.tar.gz -C /tmp && cp /tmp/system/* /conf/system/ && rm /conf/system/20-generated.conf && cp /tmp/transaction-store-id-migrations.json /conf/"
docker stop conf-restore-container

echo "Restoring Postgres backup"
docker cp ${BACKUP_PATH}/postgres.sql.gz ${DOCKER_PROJECT}_postgres_1:/tmp
docker exec ${DOCKER_PROJECT}_postgres_1 sh -c \
  "psql -U topaz topaz-main -c 'DROP TABLE public.journal; DROP TABLE public.snapshot;' && gunzip -c /tmp/postgres.sql.gz | psql -U topaz topaz-main && rm /tmp/postgres.sql.gz"

echo "Restoring Redis backup"
docker exec ${DOCKER_PROJECT}_redis_1 sh -c "redis-cli save"
docker stop ${DOCKER_PROJECT}_redis_1
docker create --rm --name redis-restore-container -v ${DOCKER_PROJECT}_redis-data:/data topaztechnology/base:3.11.3
docker start redis-restore-container
docker cp ${BACKUP_PATH}/redis.tar.gz redis-restore-container:/tmp
docker exec redis-restore-container sh -c "tar xzvf /tmp/redis.tar.gz -C /data"
docker stop redis-restore-container
docker start ${DOCKER_PROJECT}_redis_1

echo "Removing stale Monet & flatbuffers data"
docker stop ${DOCKER_PROJECT}_monet_1
docker create --rm --name monet-delete-container -v ${DOCKER_PROJECT}_monet-data:/data topaztechnology/base:3.11.3
docker start monet-delete-container
docker exec monet-delete-container sh -c "rm -rf /data/*"
docker stop monet-delete-container
docker start ${DOCKER_PROJECT}_monet_1
docker create --rm --name topaz-delete-container -v ${DOCKER_PROJECT}_topaz-data:/data -v ${DOCKER_PROJECT}_topaz-shared:/shared topaztechnology/base:3.11.3
docker start topaz-delete-container
docker exec topaz-delete-container sh -c "rm -rf /data/* && rm -rf /shared/*"
docker stop topaz-delete-container

echo "Starting Topaz container"
docker start ${DOCKER_PROJECT}_topaz_1
