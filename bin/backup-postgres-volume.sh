#!/bin/bash

# Usage: backup-postgres-volume.sh <FULL PATH>
docker run -it --rm -v compose_postgres-data:/data -v $1:/backup alpine \
    tar -cjf /backup/topaz-postgres.tar.bz2 -C /data ./
