FROM golang:1.12
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go start.sh ./
RUN go build -gcflags='-l=4' -o main
CMD bash start.sh
