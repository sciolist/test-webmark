FROM node:12
COPY package.json .
COPY package-lock.json .
RUN npm install
COPY . .
CMD node cluster.js
