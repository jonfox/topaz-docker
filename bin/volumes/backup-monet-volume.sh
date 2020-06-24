#!/bin/bash

# Usage: backup-monet-volume.sh <FULL PATH>
docker run -it --rm -v compose_monet-data:/data -v $1:/backup \
    topaztechnology/base:3.12.0 tar -cjf /backup/topaz-monet.tar.bz2 -C /data ./
