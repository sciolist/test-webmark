FROM golang:1.17.1
WORKDIR /app

COPY go.* ./
RUN go mod download

COPY *.go start.sh ./
RUN go get app
RUN go build -gcflags='-l=4' -o main
CMD bash start.sh
