FROM node:13
COPY package.json .
#COPY package-lock.json .
RUN npm install
COPY . .
CMD node cluster.js
