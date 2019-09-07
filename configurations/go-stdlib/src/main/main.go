package main

import (
	"net/http"
	"io"
	"strconv"
	"strings"
	"flag"
	"log"
	"runtime"
	"encoding/json"

	"github.com/jackc/pgx"
)

var (
	db *pgx.ConnPool
)

type Fortune struct {
	Id int32 `json:"id"`
	Message string `json:"message"`
}

type Fortunes []Fortune

func main() {
	child := flag.Bool("child", false, "")
	flag.Parse()

	var err error
	var config pgx.ConnPoolConfig
	config.Host = "db"
	config.User = "app"
	config.Password = "app"
	config.Database = "app"
	config.Port = 5432
	config.MaxConnections = runtime.NumCPU()
	pool, err := pgx.NewConnPool(config)
	db = pool

	if err != nil {
		log.Fatalf("Error opening database: %s", err)
	}

	http.HandleFunc("/10-fortunes", fortuneHandler);
	http.HandleFunc("/all-fortunes", allFortunesHandler);
	http.HandleFunc("/helloworld", helloworldHandler);
	http.HandleFunc("/primes", primesHandler);

	ln := DoPrefork(*child, ":3000")
	if err = http.Serve(ln, nil); err != nil {
		log.Fatalf("could not start server: %s", err)
	} else {
		log.Printf("listening on 3000")
	}
}

func helloworldHandler(w http.ResponseWriter, r *http.Request) {
	io.WriteString(w,"Hello, World!")
}

func primesHandler(w http.ResponseWriter, r *http.Request) {
	list := []string{}
	for test := 0; test <= 10000; test++ {
		ok := true
		for v := 2; v < test; v++ {
			if test % v != 0 {
				continue;
			}
			ok = false;
			break;
		}
		if (ok) {
			list = append(list, strconv.Itoa(test));
		}
	}
    io.WriteString(w,strings.Join(list, "\n"))
}

func fortuneHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("select id, message from fortunes limit 10")
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
	rows, err := db.Query("select id, message from fortunes")
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
