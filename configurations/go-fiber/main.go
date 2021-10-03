package main

import (
	"context"
	"fmt"
	"log"
	"strings"

	"github.com/gofiber/fiber/v2"
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
	initDatabase()

	config := fiber.Config{
		CaseSensitive:            true,
		StrictRouting:            true,
		DisableHeaderNormalizing: true,
		Prefork:                  true,
	}

	app := fiber.New(config)
	app.Use(func(c *fiber.Ctx) error {
		switch c.Path() {
		case "/10-fortunes":
			fortuneHandler(c)
		case "/all-fortunes":
			allFortunesHandler(c)
		case "/helloworld":
			helloworldHandler(c)
		case "/primes":
			primesHandler(c)
		}
		return nil
	})

	log.Fatal(app.Listen(":3000"))
}

func initDatabase() {
	var err error
	db, err = pgxpool.Connect(
		context.Background(),
		"host=webmarkdb port=5432 user=postgres password=webmark dbname=postgres pool_max_conns=150",
	)
	if err != nil {
		panic(err)
	}
}

func fortuneHandler(c *fiber.Ctx) error {
	rows, err := db.Query(context.Background(), "select id, message from fortunes limit 10")
	if err != nil {
		log.Fatalf("Error selecting db data: %v", err)
		return err
	}

	defer rows.Close()
	list := make([]Fortune, 0, 10)
	for rows.Next() {
		f := Fortune{}
		err := rows.Scan(&f.Id, &f.Message)
		if err != nil {
			log.Fatalf("Row scan error: %v", err)
			return err
		}
		list = append(list, f)
	}

	return c.JSON(&list)
}

func allFortunesHandler(c *fiber.Ctx) error {
	rows, err := db.Query(context.Background(), "select id, message from fortunes")
	if err != nil {
		log.Fatalf("Error selecting db data: %v", err)
		return err
	}

	defer rows.Close()
	list := make([]Fortune, 0, 1000)
	for rows.Next() {
		f := Fortune{}
		err := rows.Scan(&f.Id, &f.Message)
		if err != nil {
			log.Fatalf("Row scan error: %v", err)
			return err
		}
		list = append(list, f)
	}

	return c.JSON(&list)
}

func helloworldHandler(c *fiber.Ctx) error {
	return c.SendString("Hello, World!")
}

func primesHandler(c *fiber.Ctx) error {
	var out strings.Builder
	for test := 2; test <= 10000; test++ {
		ok := true
		for v := 2; v < test; v++ {
			if test%v == 0 {
				ok = false
				break
			}
		}
		if ok {
			fmt.Fprintf(&out, "%d\n", test)
		}
	}
	return c.SendString(out.String())
}