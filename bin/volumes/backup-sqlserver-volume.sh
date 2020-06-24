#!/bin/bash

# Usage: backup-sqlserver-volume.sh <FULL PATH>
docker run -it --rm -v compose_sqlserver-data:/data -v $1:/backup \
    topaztechnology/base:3.12.0 tar -cjf /backup/topaz-sqlserver.tar.bz2 -C /data ./
