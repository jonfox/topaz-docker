#!/bin/bash

set -eo pipefail

# Compose file - config related to Docker Compose stack

function akkaDockerCompose {
  # This is needed to tell Akka Cluster to find other nodes in the cluster by hostname.
  # We assume there are at least 3 nodes in the cluster: topaz, topaz-compute-1, and topaz-compute-2
  cat >> ${COMPOSE_CONF_FILE} <<-'EOF'
akka {
  remote.artery.canonical.hostname = ${?HOSTNAME}

  discovery {
    method = config

    config.services = {
      topaz-cluster = {
        endpoints = [
          {
            host = "topaz"
          },
          {
            host = "topaz-compute-1"
          },
          {
            host = "topaz-compute-2"
          }
        ]
      }
    }
  }

  management.http.hostname = ${?HOSTNAME}
}

EOF
}

function createCerts {
  openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
    -keyout ${GENERATED_CERTS_DIR}/${EXTERNAL_HOSTNAME}.key \
    -subj "/C=GB/L=London/O=Topaz/CN="${EXTERNAL_HOSTNAME} \
    -reqexts SAN \
    -config <(cat /etc/ssl/openssl.cnf \
      <(printf "\n[SAN]\nsubjectAltName=DNS:"${EXTERNAL_HOSTNAME})) \
    -out ${GENERATED_CERTS_DIR}/${EXTERNAL_HOSTNAME}.crt
}

function configureBehindIngress {
  cat >> ${COMPOSE_CONF_FILE} <<-EOF
topaz.kernel-service {
  ssl.status = behind-ingress
  getdown.port = 443
}

EOF
}

# Host file - config related to host name / discovery

function discoverHostname {
  if [[ -f "/etc/hostname" ]]; then
    # Should work on Linux
    EXTERNAL_HOSTNAME=$(cat /etc/hostname)
  elif [[ -f "/usr/bin/hostname" ]]; then
    # Should work on Windows MSYS
    EXTERNAL_HOSTNAME=$(/usr/bin/hostname)
  elif [[ -f "/usr/sbin/scutil" ]]; then
    # Should work on macOS
    EXTERNAL_HOSTNAME=$(/usr/sbin/scutil --get LocalHostName)
  else
    echo "Error: Cannot find hostname at /etc/hostname, using /usr/bin/hostname or using scutil"
    exit 1
  fi
}

function configureHostname {
  cat >> ${HOST_CONF_FILE} <<-EOF
topaz.kernel-service.external-hostname = ${EXTERNAL_HOSTNAME}

EOF
}

function configureHashingPepper {
  cat >> ${HOST_CONF_FILE} <<-EOF
topaz.auth-store.password-hashing-pepper = "${PASSWORD_HASHING_PEPPER}"

EOF
}

# DB file - config related to databases

function configureBackendH2 {
  cat >> ${DB_CONF_FILE} <<-EOF
topaz.event-store.backend.$1 = H2

h2-$1.db.url = "jdbc:h2:/opt/topaz/data/topaz-$1;DATABASE_TO_UPPER=false;EARLY_FILTER=true;AUTO_SERVER=true"

EOF
}

function configureBackendPostgres {
  cat >> ${DB_CONF_FILE} <<-EOF
topaz.event-store.backend.$1 = Postgres

postgres-$1.db.url = "jdbc:postgresql://postgres/topaz_$1?reWriteBatchedInserts=true"

EOF
}

function configureBackendSQLServer {
  cat >> ${DB_CONF_FILE} <<-EOF
topaz.event-store.backend.$1 = SQLServer

sqlserver-$1.db.url = "jdbc:sqlserver://sqlserver:1433;DatabaseName=Topaz$2"

EOF
}

function configureMainBackendCassandra {
  cat >> ${DB_CONF_FILE} <<-EOF
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
  cat >> ${DB_CONF_FILE} <<-EOF
topaz.event-store.backend.tick = Redis
redis-tick {
  mode = simple
  host = redis
}

EOF
}

function configurePivotH2 {
  cat >> ${DB_CONF_FILE} <<-EOF
topaz.pivot-store.db {
  type = "H2"
  url = "jdbc:h2:/opt/topaz/data/topaz-pivot;DATABASE_TO_UPPER=false;EARLY_FILTER=true;AUTO_SERVER=true"
  user = "root"
  password = "root"
  driver = "org.h2.Driver"
  max-readonly-retries = 3
}

EOF
}

function configurePivotMonet {
  cat >> ${DB_CONF_FILE} <<-EOF
topaz.pivot-store.db {
  type = "Monet"
  url = "jdbc:monetdb://monet:50000/topaz-pivot"
  user = "monetdb"
  password = "monetdb"
  driver = "nl.cwi.monetdb.jdbc.MonetDriver"
  max-readonly-retries = 3
}

EOF
}

# Main
function usage {
  echo "This script produces the configuration volume and optionally the certificate volume for Topaz running on docker-compose"
  echo
  echo "Options:"
  echo "  -t, --test                 Use test config (smaller memory limits, bigger timeouts)"
  echo "  -h, --hostname <hostname>  The external hostname to use"
  echo "  -d, --discover-hostname    Try to discover the hostname, should work on Linux, Mac, and Windows MSYS"
  echo "  -g, --generate-certs       Generate a self signed cert to use with nginx"
  echo "  -c, --certs <certs path>   Copy certs from path specified. There should be two files, in the form <FQDN>.key and <FQDN>.crt"
  echo "  -P, --pepper <pepper>      The password hashing pepper to use"
  echo
  echo "Supported databases: h2, postgres, sqlserver, cassandra"
  echo "  -m, --main-db <database type>   Specify the database type for the main store"
  echo "  -k, --tick-db <database type>   Specify the database type for the tick store"
  echo "  -p, --pivot-db <database type>  Specify the database type for the pivot store"
}

if [[ "$#" -eq 0 ]]; then
  usage
  exit 0
fi

while (( "$#" )); do
  case "$1" in
    -t|--test)
      TEST_CONF=1
      shift
      ;;
    -d|--discover-hostname)
      DISCOVER_HOSTNAME=1
      shift
      ;;
    -h|--hostname)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        EXTERNAL_HOSTNAME=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -g|--generate-certs)
      CREATE_CERTS=1
      shift
      ;;
    -c|--certs)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        PROVIDED_CERTS_DIR=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -P|--pepper)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        PASSWORD_HASHING_PEPPER=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
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
    -k|--tick-db)
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


COMPOSE_CONF_FILE=$(mktemp -t 15-compose.XXXXXXXX)
HOST_CONF_FILE=$(mktemp -t 20-host.XXXXXXXX)
DB_CONF_FILE=$(mktemp -t 25-db.XXXXXXXX)
GENERATED_CERTS_DIR=$(mktemp -d -t certs-XXXXXXXX)

if [[ -n "${DISCOVER_HOSTNAME}" ]]; then
  discoverHostname
fi

if [[ -z "${EXTERNAL_HOSTNAME}" ]]; then
  echo "Error: No hostname found, please use -d to discover, or -h <hostname> to specify"
  exit 1
fi

akkaDockerCompose

configureHostname

if [[ -n "${CREATE_CERTS}" ]]; then
  createCerts
fi

if [[ -n "${CREATE_CERTS}" || -n "${PROVIDED_CERTS_DIR}" ]]; then
  configureBehindIngress
fi

if [[ -n "${PASSWORD_HASHING_PEPPER}" ]]; then
  configureHashingPepper
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

if [[ -s "${COMPOSE_CONF_FILE}" ]]; then
  docker cp ${COMPOSE_CONF_FILE} topaz-conf-container:/conf/system/15-compose.conf
fi


if [[ -s "${HOST_CONF_FILE}" ]]; then
  docker cp ${HOST_CONF_FILE} topaz-conf-container:/conf/system/20-host.conf
fi

if [[ -s "${DB_CONF_FILE}" ]]; then
  docker cp ${DB_CONF_FILE} topaz-conf-container:/conf/system/25-db.conf
fi

docker rm topaz-conf-container

if [[ -n "${CREATE_CERTS}" || -n "${PROVIDED_CERTS_DIR}" ]]; then
  docker volume create topaz-certs
  docker create --name topaz-certs-container -v topaz-certs:/certs topaztechnology/base:3.12.0
  if [[ -n "${PROVIDED_CERTS_DIR}" ]]; then
    docker cp ${PROVIDED_CERTS_DIR}/. topaz-certs-container:/certs/
  else
    docker cp ${GENERATED_CERTS_DIR}/. topaz-certs-container:/certs/
  fi
  docker rm topaz-certs-container
fi

rm ${COMPOSE_CONF_FILE}
rm ${HOST_CONF_FILE}
rm ${DB_CONF_FILE}
rm -r ${GENERATED_CERTS_DIR}
