#!/bin/sh
set -ue
export ROOT="$(cd $(dirname $(dirname "$0")) && pwd)"
COMPOSEFILE="docker-compose.nodb.yml"

if [ -z "${PGHOST:-}" ]
then
    export PGUSER="app"
    export PGPASSWORD="app"
    export PGDATABASE="app"
    export PGHOST="db"
    export PGPORT="5432"
    COMPOSEFILE="docker-compose.yml"
fi

started=0
while [ $started -eq 0 ]
do
    docker ps -q | while read id
    do
        docker stop "$id"
    done
    docker-compose --project-directory "${ROOT}" --file "${COMPOSEFILE}" build >&2
    docker-compose --project-directory "${ROOT}" --file "${COMPOSEFILE}"  up --detach --force-recreate --remove-orphans
    container_id=$(docker-compose --project-directory "${ROOT}" --file "${COMPOSEFILE}"  ps -q api)
    echo "CONTAINER=$container_id"

    iter = 0
    while [ $iter -lt 10 ]
    do
        let iter = iter + 1
        code=$(curl --max-time 5.5 -sL -w "%{http_code}\\n" "$URL/10-fortunes" -o /dev/null || true)
        if [ $code -eq 200 ]
        then
            exit 0
        fi
        echo "waiting for 200 response..." >&2
        sleep 3
    done
    echo "docker container seems to be dead, lets retry."
done

echo "docker container started"
