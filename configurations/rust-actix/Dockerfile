FROM rust:1.61.0
WORKDIR /app
COPY Cargo* ./
RUN mkdir src && echo "fn main() { }" > src/main.rs
RUN cargo build --release
RUN rm ./target/release/app*
RUN rm ./target/release/deps/app*
COPY . .
RUN SQLX_OFFLINE=true cargo build --release
CMD DATABASE_URL=postgresql://postgres:webmark@webmarkdb:5432/postgres target/release/app
