#!/bin/bash

# Usage: backup-postgres-redis-conf.sh <FULL PATH> [DOCKER PROJECT]

set -eo pipefail

BACKUP_PATH=$1

if [ -z "$2" ]; then
  DOCKER_PROJECT=$(basename `pwd`)
else
  DOCKER_PROJECT=$2
fi

######## Backup conf ########
docker exec ${DOCKER_PROJECT}_topaz_1 sh -c "tar -czf /tmp/conf.tar.gz -C /opt/topaz/conf ."
docker cp ${DOCKER_PROJECT}_topaz_1:/tmp/conf.tar.gz ${BACKUP_PATH}

######## Backup Postgres ########
docker exec ${DOCKER_PROJECT}_postgres_1 sh -c \
  "pg_dump -Fc -v -U topaz -d topaz_tick -f /tmp/topaz_tick.dump && pg_dump -Fc -v -U topaz -d topaz_main -f /tmp/topaz_main.dump"
docker cp ${DOCKER_PROJECT}_postgres_1:/tmp/topaz_main.dump ${BACKUP_PATH}
docker cp ${DOCKER_PROJECT}_postgres_1:/tmp/topaz_tick.dump ${BACKUP_PATH}
