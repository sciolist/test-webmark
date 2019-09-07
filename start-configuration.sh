#!/bin/sh
set -ue
stop=$(docker stop $(docker ps -q) || true)
docker-compose build >&2
docker-compose up --detach --force-recreate --remove-orphans
container_id=$(docker-compose ps -q api)
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
