#!/bin/bash

docker volume rm topaz-conf
docker volume create topaz-conf
docker create --name topaz-conf-container -v topaz-conf:/conf topaztechnology/base:3.6
docker cp conf/. topaz-conf-container:/conf
docker rm topaz-conf-container
