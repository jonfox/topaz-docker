#!/bin/bash

# Usage: backup-conf-volume.sh <FULL PATH>
docker run -it --rm -v topaz-conf:/conf -v $1:/backup topaztechnology/base:3.6 \
    tar -cjf /backup/topaz-conf.tar.bz2 -C /conf ./
