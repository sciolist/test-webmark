FROM golang:1.13.5
WORKDIR /app

COPY go.* ./
RUN go mod download

COPY *.go start.sh ./
RUN go build -gcflags='-l=4' -o main
CMD bash start.sh
