#!/bin/bash

# Usage: replace-redis-from-backup.sh <FULL PATH>
docker run -it --rm -v compose_redis-data:/data -v $1:/backup alpine \
    sh -c "rm -rf /data/* /data/..?* /data/.[!.]* ; tar -C /data/ -xjf /backup/topaz-redis.tar.bz2"
