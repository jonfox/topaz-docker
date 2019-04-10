#!/bin/bash

# Usage: restore-conf-volume.sh <FULL PATH>
docker run --rm -v topaz-conf:/conf -v $1:/backup topaztechnology/base:3.6 \
    tar -xzf /backup/conf.tar.gz -C /conf .
