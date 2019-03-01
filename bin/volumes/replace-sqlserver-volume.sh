#!/bin/bash

# Usage: replace-sqlserver-from-backup.sh <FULL PATH>
docker run -it --rm -v compose_sqlserver-data:/data -v $1:/backup \
    topaztechnology/base:3.6 \
    sh -c "rm -rf /data/* /data/..?* /data/.[!.]* ; tar -C /data/ -xjf /backup/topaz-sqlserver.tar.bz2"
