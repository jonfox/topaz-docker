#!/bin/bash

# Usage: backup-conf-volume.sh <FULL PATH>
docker run --rm -v topaz-conf:/conf -v $1:/backup topaztechnology/base:3.12.0 \
  tar -czf /backup/conf.tar.gz -C /conf .
