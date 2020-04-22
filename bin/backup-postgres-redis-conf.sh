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
docker exec ${DOCKER_PROJECT}_postgres_1 sh -c "pg_dump -U topaz topaz-main | gzip > /tmp/postgres.sql.gz"
docker cp ${DOCKER_PROJECT}_postgres_1:/tmp/postgres.sql.gz ${BACKUP_PATH}

######## Backup Redis ########
docker exec ${DOCKER_PROJECT}_redis_1 sh -c "redis-cli save; tar -czf /tmp/redis.tar.gz -C /redis/data ."
docker cp ${DOCKER_PROJECT}_redis_1:/tmp/redis.tar.gz ${BACKUP_PATH}
