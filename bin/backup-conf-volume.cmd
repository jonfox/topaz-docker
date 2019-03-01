REM Usage: backup-conf-volume <FULL PATH>

docker run --rm -v topaz-conf:/conf -v %1:/backup topaztechnology/base:3.6 tar -czf /backup/topaz-conf.tar.gz -C /conf .
