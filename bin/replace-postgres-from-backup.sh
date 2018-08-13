#!/bin/bash

# Usage: replace-postgres-from-backup.sh <FULL PATH>
docker run -it --rm -v compose_postgres-data:/data -v $1:/backup \
    topaztechnology/base:3.6 \
    sh -c "rm -rf /data/* /data/..?* /data/.[!.]* ; tar -C /data/ -xjf /backup/topaz-postgres.tar.bz2"
