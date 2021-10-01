FROM golang:1.16
WORKDIR /app

COPY go.* ./
RUN go mod download

COPY *.go start.sh ./
RUN go get app
RUN go build -gcflags='-l=4' -o main
CMD bash start.sh
