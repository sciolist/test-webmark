FROM crystallang/crystal:1.1.1
WORKDIR /app
COPY shard.* ./
RUN shards install
COPY . .
RUN crystal build --release --no-debug ./app.cr
CMD bash cluster.sh
