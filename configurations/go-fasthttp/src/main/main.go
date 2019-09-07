package main

import (
	"strconv"
	"strings"
	"flag"
	"log"
	"runtime"
	"encoding/json"

	"github.com/jackc/pgx"
	"github.com/valyala/fasthttp"
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
	child := flag.Bool("child", false, "is child proc")
	flag.Parse()

	var err error
	var config pgx.ConnPoolConfig
	config.ConnConfig, err = pgx.ParseEnvLibpq()
	if err != nil {
		log.Fatalf("Error getting database config: %s", err)
	}
	config.MaxConnections = 50 / runtime.NumCPU()
	pool, err := pgx.NewConnPool(config)
	db = pool

	if err != nil {
		log.Fatalf("Error opening database: %s", err)
	}

	server := &fasthttp.Server { Handler: handler }
	ln := DoPrefork(*child, ":3000")
	if err = server.Serve(ln); err != nil {
		log.Fatalf("could not start server: %s", err)
	}
}

func handler(ctx *fasthttp.RequestCtx) {
	path := ctx.Path()
	switch string(path) {
	case "/helloworld":
		helloworldHandler(ctx)
	case "/10-fortunes":
		fortuneHandler(ctx)
	case "/all-fortunes":
		allFortunesHandler(ctx)
	case "/primes":
		primesHandler(ctx)
	default:
		ctx.Error("404", fasthttp.StatusBadRequest)
	}
}

func helloworldHandler(ctx *fasthttp.RequestCtx) {
	ctx.WriteString("Hello, World!")
}

func primesHandler(ctx *fasthttp.RequestCtx) {
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
	
	ctx.SetContentType("application/json")
	ctx.WriteString(strings.Join(list,"\n"))
}

func fortuneHandler(ctx *fasthttp.RequestCtx) {
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
	ctx.SetContentType("application/json")
	ctx.Write(wb)
}


func allFortunesHandler(ctx *fasthttp.RequestCtx) {
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
	ctx.SetContentType("application/json")
	ctx.Write(wb)
}
