FROM crystallang/crystal:0.30.1
WORKDIR /app
COPY shard.yml shard.lock ./
RUN shards install
COPY . .
RUN crystal build --release --no-debug ./app.cr
CMD bash cluster.sh
