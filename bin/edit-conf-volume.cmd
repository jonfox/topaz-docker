docker create --name topaz-conf-container -v topaz-conf:/conf topaztechnology/base:3.6
docker start topaz-conf-container
docker exec -it topaz-conf-container /bin/bash
