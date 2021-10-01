FROM node:16.9.1
WORKDIR /work
COPY package*.json ./
RUN npm install
COPY *.js ./
ENV NODE_ENV production
CMD ["node", "cluster.js"]
