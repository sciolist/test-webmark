#!/bin/bash
sleep 5
cp shard.lock /src/shard.lock
for i in $(seq 1 $(nproc --all)); do
  ./app &
done
wait