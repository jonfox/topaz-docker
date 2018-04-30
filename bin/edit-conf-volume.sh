#!/bin/bash

docker create --name topaz-conf-container -v topaz-conf:/conf topaztechnology/base:3.6
docker start topaz-conf-container
exec docker exec -it topaz-conf-container /bin/bash
