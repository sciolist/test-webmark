#!/bin/bash
sleep 5
for i in $(seq 1 $(nproc --all)); do
  ./app &
done
wait