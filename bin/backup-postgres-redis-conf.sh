#!/bin/bash

######## Backup conf ########
docker exec compose_topaz_1 sh -c "tar -czf /tmp/conf.tar.gz -C /opt/topaz/conf ."
docker cp compose_topaz_1:/tmp/conf.tar.gz /backup

######## Backup Postgres ########
docker exec compose_postgres_1 sh -c "pg_dump -U topaz topaz-main | gzip > /tmp/postgres.sql.gz"
docker cp compose_postgres_1:/tmp/postgres.sql.gz /backup

######## Backup Redis ########
docker exec compose_redis_1 sh -c "redis-cli save; tar -czf /tmp/redis.tar.gz -C /redis/data ."
docker cp compose_redis_1:/tmp/redis.tar.gz /backup
