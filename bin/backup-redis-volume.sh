#!/bin/bash

# Usage: backup-redis-volume.sh <FULL PATH>
docker run -it --rm -v compose_redis-data:/data -v $1:/backup alpine \
    tar -cjf /backup/topaz-redis.tar.bz2 -C /data ./
