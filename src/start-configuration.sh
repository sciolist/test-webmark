#!/bin/sh
set -ue
export ROOT="$(cd $(dirname $(dirname "$0")) && pwd)"

docker ps -q | while read id
do
    docker stop "$id"
done

docker-compose --project-directory "${ROOT}" build >&2
docker-compose --project-directory "${ROOT}" up --detach --force-recreate --remove-orphans
container_id=$(docker-compose --project-directory "${ROOT}" ps -q api)
echo "CONTAINER=$container_id"

while true
do
    code=$(curl -sL -w "%{http_code}\\n" "$URL/10-fortunes" -o /dev/null || true)
    if [ $code -eq 200 ]
    then
        exit 0
    fi
    echo "waiting for 200 response..." >&2
    sleep 3
done

echo "docker container running"
