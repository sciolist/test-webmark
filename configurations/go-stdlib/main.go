package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/jackc/pgx/v4/pgxpool"
)

var (
	db *pgxpool.Pool
)

type Fortune struct {
	Id      int32  `json:"id"`
	Message string `json:"message"`
}

type Fortunes []Fortune

func main() {
	child := flag.Bool("child", false, "")
	flag.Parse()
	initDatabase(*child)

	http.HandleFunc("/10-fortunes", fortuneHandler)
	http.HandleFunc("/all-fortunes", allFortunesHandler)
	http.HandleFunc("/helloworld", helloworldHandler)
	http.HandleFunc("/primes", primesHandler)

	ln := DoPrefork(*child, ":3000")
	if err := http.Serve(ln, nil); err != nil {
		log.Fatalf("could not start server: %s", err)
	} else {
		log.Printf("listening on 3000")
	}
}

func initDatabase(child bool) {
	var err error
	db, err = pgxpool.Connect(
		context.Background(),
		"host=webmarkdb port=5432 user=postgres password=webmark dbname=postgres pool_max_conns=150",
	)
	if err != nil {
		panic(err)
	}
}

func helloworldHandler(w http.ResponseWriter, r *http.Request) {
	io.WriteString(w, "Hello, World!")
}

func primesHandler(w http.ResponseWriter, r *http.Request) {
	for test := 2; test <= 10000; test++ {
		ok := true
		for v := 2; v < test; v++ {
			if test%v == 0 {
				ok = false
				break
			}
		}
		if ok {
			fmt.Fprintf(w, "%d\n", test)
		}
	}
}

func fortuneHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(context.Background(), "select id, message from fortunes limit 10")
	if err != nil {
		log.Fatalf("Error selecting db data: %v", err)
	}

	defer rows.Close()
	list := make([]Fortune, 0, 10)
	for rows.Next() {
		f := Fortune{}
		err := rows.Scan(&f.Id, &f.Message)
		if err != nil {
			log.Fatalf("Row scan error: %v", err)
		}
		list = append(list, f)
	}

	wb, err := json.Marshal(list)
	if err != nil {
		log.Println(err)
		return
	}
	w.Write(wb)
}

func allFortunesHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(context.Background(), "select id, message from fortunes")
	if err != nil {
		log.Fatalf("Error selecting db data: %v", err)
	}

	list := make([]Fortune, 0, 1000)
	for rows.Next() {
		f := Fortune{}
		err := rows.Scan(&f.Id, &f.Message)
		if err != nil {
			log.Fatalf("Row scan error: %v", err)
		}
		list = append(list, f)
	}

	wb, err := json.Marshal(list)
	if err != nil {
		log.Println(err)
		return
	}
	w.Write(wb)
}
