FROM node:18
WORKDIR /work
COPY package*.json ./
RUN npm install
COPY *.js ./
ENV NODE_ENV production
CMD ["node", "cluster.js"]
