FROM ubuntu:22.04
RUN apt-get -yqq update && apt-get -yqq install unzip wget
WORKDIR /tmp
RUN wget https://ziglang.org/download/0.9.1/zig-linux-x86_64-0.9.1.tar.xz
RUN apt-get -yqq install xz-utils
RUN tar -xf zig-linux-x86_64-0.9.1.tar.xz
RUN mv zig-linux-x86_64-0.9.1 /zig
WORKDIR /work
COPY . .
RUN /zig/zig build -Drelease-fast
CMD zig-out/bin/zig-test
