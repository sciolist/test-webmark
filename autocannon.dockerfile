FROM node:16.1
RUN npm install -g autocannon
CMD autocannon
