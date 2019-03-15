#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "$0 <password> <pepper>"
    exit 1
fi

if [[ ! -x $(which htpasswd) ]]; then
    echo "htpasswd not found; install apache2-utils package"
    exit 2
fi

htpasswd -bnBC 12 "" "$1$2" | tr -d ':\n' | sed 's/$2y/$2a/'
