FROM rust:1.37
COPY Cargo.toml .
COPY Cargo.lock .
RUN mkdir src && echo "fn main() { }" > src/main.rs
RUN cargo build --release
RUN rm ./target/release/app*
RUN rm ./target/release/deps/app*
COPY . .
RUN cargo build --release
CMD target/release/app
