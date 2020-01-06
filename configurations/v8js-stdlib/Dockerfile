FROM node:13
WORKDIR /app
COPY package* ./
RUN npm install
COPY . .
CMD bash start.sh
