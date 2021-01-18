#!/bin/bash

set -eo pipefail

if [ "$#" -lt 1 ]; then
  echo "syntax: $0 <full backup path> [docker project]"
  exit 1
fi

BACKUP_PATH=$1

if [ -z "$2" ]; then
  DOCKER_PROJECT=$(basename `pwd`)
else
  DOCKER_PROJECT=$2
fi

echo "Stopping Topaz containers"
docker stop ${DOCKER_PROJECT}_topaz_1
docker stop ${DOCKER_PROJECT}_topaz-compute-1_1
docker stop ${DOCKER_PROJECT}_topaz-compute-2_1

echo "Restoring Postgres backup"
docker cp ${BACKUP_PATH}/topaz_main.dump ${DOCKER_PROJECT}_postgres_1:/tmp/
docker cp ${BACKUP_PATH}/topaz_tick.dump ${DOCKER_PROJECT}_postgres_1:/tmp/
docker exec ${DOCKER_PROJECT}_postgres_1 sh -c \
  "pg_restore -v -U topaz -d topaz_main --no-owner --clean --no-acl /tmp/topaz_main.dump && pg_restore -v -U topaz -d topaz_tick --no-owner --clean --no-acl /tmp/topaz_tick.dump"

echo "Removing stale Monet & flatbuffers data"
docker stop ${DOCKER_PROJECT}_monet_1
docker create --rm --name monet-delete-container -v ${DOCKER_PROJECT}_monet-data:/data topaztechnology/base:3.12.0
docker start monet-delete-container
docker exec monet-delete-container sh -c "rm -rf /data/*"
docker stop monet-delete-container
docker start ${DOCKER_PROJECT}_monet_1
docker create --rm --name topaz-delete-container -v ${DOCKER_PROJECT}_topaz-data:/data -v ${DOCKER_PROJECT}_topaz-shared:/shared topaztechnology/base:3.12.0
docker start topaz-delete-container
docker exec topaz-delete-container sh -c "rm -rf /data/* && rm -rf /shared/*"
docker stop topaz-delete-container

echo "Starting Topaz containers"
docker start ${DOCKER_PROJECT}_topaz_1
docker start ${DOCKER_PROJECT}_topaz-compute-1_1
docker start ${DOCKER_PROJECT}_topaz-compute-2_1
