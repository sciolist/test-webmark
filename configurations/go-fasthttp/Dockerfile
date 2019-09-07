FROM golang:1.12
WORKDIR /fasthttp

RUN mkdir bin
ENV GOPATH /fasthttp
ENV PATH ${GOPATH}/bin:${PATH}

RUN go get -d -u github.com/jackc/pgx
RUN go get -d -u github.com/valyala/fasthttp/...

COPY . .
RUN go build -gcflags='-l=4' main
CMD bash start.sh