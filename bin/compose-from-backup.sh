#!/bin/bash

# Expects Postgres & Redis currently

if [[ $# -ne 2 ]]; then
  echo "$0 <compose project> <backup path>"
  exit 1
fi

COMPOSE_PROJECT=$1
BACKUP_DIR=$2

if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo "Backup directory not found: ${BACKUP_DIR}"
  exit 2
fi

TOPAZ_CONTAINER=${COMPOSE_PROJECT}_topaz_1
POSTGRES_CONTAINER=${COMPOSE_PROJECT}_postgres_1
REDIS_CONTAINER=${COMPOSE_PROJECT}_redis_1
MONET_CONTAINER=${COMPOSE_PROJECT}_monet_1

set -eo pipefail

# Set up config volume
echo "Creating conf volume"
docker volume create topaz-conf
docker run --rm --name topaz-conf-container -v topaz-conf:/conf -v $BACKUP_DIR:/backup -d topaztechnology/base:3.8
# We don't want the generated file or the SSL files, they will contain the external-hostname which will not be correct
docker exec topaz-conf-container sh -c 'tar zxvf /backup/conf.tar.gz -C /conf . && rm /conf/system/20-generated.conf && rm -r /conf/ssl/'
docker stop topaz-conf-container

echo "Starting inital docker stack"
docker-compose -p ${COMPOSE_PROJECT} -f ../compose/postgres-redis-topaz-linux.yml up -d

echo "Waiting for Topaz to become healthy"
while [ $(docker inspect -f {{.State.Running}} ${TOPAZ_CONTAINER}) != "true" ]; do sleep 1; done
sleep 10
#while [ $(docker inspect -f {{.State.Health.Status}} ${TOPAZ_CONTAINER}) != "healthy" ]; do sleep 1; done

echo "Stopping Topaz container"
docker stop ${TOPAZ_CONTAINER}

echo "Restoring Postgres backup"
docker cp ${BACKUP_DIR}/postgres.sql.gz ${POSTGRES_CONTAINER}:/tmp
docker exec ${POSTGRES_CONTAINER} sh -c "psql -U topaz topaz-main -c 'DROP TABLE public.journal; DROP TABLE public.snapshot;' && gunzip -c /tmp/postgres.sql.gz | psql -U topaz topaz-main && rm /tmp/postgres.sql.gz"

echo "Restoring Redis backup"
docker exec ${REDIS_CONTAINER} sh -c "redis-cli save"
docker stop ${REDIS_CONTAINER}
docker create --rm --name redis-restore-container -v ${COMPOSE_PROJECT}_redis-data:/data -v ${BACKUP_DIR}:/backup topaztechnology/base:3.8
docker start redis-restore-container
docker exec redis-restore-container sh -c "tar xzvf /backup/redis.tar.gz -C /data"
docker stop redis-restore-container
docker start ${REDIS_CONTAINER}

echo "Removing stale Monet & flatbuffers data"
docker stop ${MONET_CONTAINER}
docker create --rm --name monet-delete-container -v ${COMPOSE_PROJECT}_monet-data:/data topaztechnology/base:3.8
docker start monet-delete-container
docker exec monet-delete-container sh -c "rm -rf /data/*"
docker stop monet-delete-container
docker start ${MONET_CONTAINER}
docker create --rm --name topaz-delete-container -v ${COMPOSE_PROJECT}_topaz-data:/data topaztechnology/base:3.8
docker start topaz-delete-container
docker exec topaz-delete-container sh -c "rm -rf /data/*"
docker stop topaz-delete-container

echo "Starting Topaz container"
docker start ${TOPAZ_CONTAINER}
