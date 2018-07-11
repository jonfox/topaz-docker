#!/bin/bash

# Usage: replace-monet-from-backup.sh <FULL PATH>
docker run -it --rm -v compose_monet-data:/data -v $1:/backup alpine \
    sh -c "rm -rf /data/* /data/..?* /data/.[!.]* ; tar -C /data/ -xjf /backup/topaz-monet.tar.bz2"
