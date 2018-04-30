#!/bin/bash

# Usage: backup-conf-volume <FULL PATH>
docker run -it -v topaz-conf:/conf -v $1:/backup alpine \
    tar -cjf /backup/topaz-conf.tar.bz2 -C /conf ./
