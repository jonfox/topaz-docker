#!/bin/bash

set -eo pipefail

function configureHostname {
  if [[ -f "/etc/hostname" ]]; then
    # Should work on Linux
    EXTERNAL_HOSTNAME=$(cat /etc/hostname)
  elif [[ -f "/usr/sbin/scutil" ]]; then
    # Should work on macOS
    EXTERNAL_HOSTNAME=$(/usr/sbin/scutil --get LocalHostName)
  fi

  if [[ -n "${EXTERNAL_HOSTNAME}" ]]; then
      cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.kernel-service.external-hostname = ${EXTERNAL_HOSTNAME}

EOF
  else
    echo "Error: Cannot find hostname at /etc/hostname or using scutil"
    exit 1
  fi
}

function configureBackendH2 {
  cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.event-store.backend.$1 = H2

h2-$1.db.url = "jdbc:h2:/opt/topaz/data/topaz-$1;DATABASE_TO_UPPER=false;EARLY_FILTER=true;AUTO_SERVER=true"

EOF
}

function configureBackendPostgres {
  cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.event-store.backend.$1 = Postgres

postgres-$1.db.url = "jdbc:postgresql://postgres/topaz-$1?reWriteBatchedInserts=true"

EOF
}

function configureBackendSQLServer {
  cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.event-store.backend.$1 = SQLServer

sqlserver-$1.db.url = "jdbc:sqlserver://sqlserver:1433;DatabaseName=Topaz$2"

EOF
}

function configureMainBackendCassandra {
  cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.event-store.backend.main = Cassandra

cassandra-journal.contact-points = [
  cassandra
]

cassandra-snapshot-store.contact-points = [
  cassandra
]

EOF
}

function configureTickBackendRedis {
  cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.event-store.backend.tick = Redis
redis-tick {
  mode = simple
  host = redis
}

EOF
}

function configurePivotH2 {
  cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.pivot-store.db {
  type = "H2"
  url = "jdbc:h2:/opt/topaz/data/topaz-pivot;DATABASE_TO_UPPER=false;EARLY_FILTER=true;AUTO_SERVER=true"
  user = "root"
  password = "root"
  driver = "org.h2.Driver"
  connectionTestQuery = "SELECT 1"
  poolName = "topaz-pivot"
}

EOF
}

function configurePivotMonet {
  cat >> ${GENERATED_CONF_FILE} <<-EOF
topaz.pivot-store.db {
  type = "Monet"
  url = "jdbc:monetdb://monet:50000/topaz-pivot"
  user = "monetdb"
  password = "monetdb"
  driver = "nl.cwi.monetdb.jdbc.MonetDriver"
  connectionTestQuery = "SELECT 1;"
  poolName = "topaz-pivot"
}

EOF
}

# Main

while (( "$#" )); do
  case "$1" in
    -t|--test)
      TEST_CONF=1
      shift
      ;;
    -h|--use-hostname)
      USE_HOSTNAME=1
      shift
      ;;
    -m|--main-db)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        MAIN_DB=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -t|--tick-db)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        TICK_DB=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -p|--pivot-db)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        PIVOT_DB=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *)
      echo "Error: Unsupported parameter $1" >&2
      exit 1
      ;;
  esac
done


GENERATED_CONF_FILE=$(mktemp /tmp/20-generated.XXXXXXXX)

if [[ -n "${USE_HOSTNAME}" ]]; then
  configureHostname
fi

case ${MAIN_DB} in
  h2)
    configureBackendH2 main
    ;;

  postgres)
    configureBackendPostgres main
    ;;

  sqlserver)
    configureBackendSQLServer main Main
    ;;

  cassandra)
    configureMainBackendCassandra
    ;;
esac

case ${TICK_DB} in
  h2)
    configureBackendH2 tick
    ;;

  postgres)
    configureBackendPostgres tick
    ;;

  sqlserver)
    configureBackendSQLServer tick Tick
    ;;

  redis)
    configureTickBackendRedis
    ;;
esac

case ${PIVOT_DB} in
  h2)
    configurePivotH2
    ;;

  monet)
    configurePivotMonet
    ;;
esac


docker volume create topaz-conf
docker create --name topaz-conf-container -v topaz-conf:/conf topaztechnology/base:3.12.0

if [[ -n "${TEST_CONF}" ]]; then
  docker cp test-conf/. topaz-conf-container:/conf
else
  docker cp conf/. topaz-conf-container:/conf
fi

if [[ -s "${GENERATED_CONF_FILE}" ]]; then
  docker cp ${GENERATED_CONF_FILE} topaz-conf-container:/conf/system/20-generated.conf
fi

docker rm topaz-conf-container
rm ${GENERATED_CONF_FILE}
