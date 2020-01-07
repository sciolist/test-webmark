#!/bin/bash
cp package-lock.json /src
NODE_ENV=production node cluster.js
