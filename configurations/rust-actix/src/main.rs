#[macro_use] extern crate serde_derive;
use actix::prelude::*;
use actix_http::{HttpService, KeepAlive};
use actix_server::Server;
use actix_web::{web, App, Error, HttpRequest};
use futures::Future;

mod database;

use crate::database::{PgConnection, FortunesAll, Fortunes10};

fn fortunes_10(db: web::Data<Addr<PgConnection>>) -> impl Future<Item = std::string::String, Error = Error> {
    db.send(Fortunes10)
        .from_err()
        .and_then(move |res| {
            Ok(serde_json::to_string(&res.unwrap()).unwrap())
        })
}

fn fortunes_all(db: web::Data<Addr<PgConnection>>) -> impl Future<Item = std::string::String, Error = Error> {
    db.send(FortunesAll)
        .from_err()
        .and_then(move |res| {
            Ok(serde_json::to_string(&res.unwrap()).unwrap())
        })
}

fn primes(_: HttpRequest) -> std::string::String {
    let mut list: Vec<String> = vec![];
    for t in 2..10001 {
        let mut ok = true;
        for v in 2..t {
            if t % v == 0 {
                ok = false;
                break;
            }
        }
        if ok {
            list.push(t.to_string());
        }
    }
    list.join("\n")
}

fn helloworld(_: HttpRequest) -> std::string::String {
    "Hello, world!".to_string()
}

fn main() -> std::io::Result<()> {
    let sys = actix_rt::System::builder().stop_on_panic(false).build();
    const DB_URL: &str = "postgres://";

    Server::build()
        .backlog(1024)
        .bind("app", "0.0.0.0:3000", || {
            let addr = PgConnection::connect(DB_URL);
            HttpService::build().keep_alive(KeepAlive::Os).h1(App::new()
                .data(addr)
                .service(web::resource("/helloworld").to(helloworld))
                .service(web::resource("/10-fortunes").to_async(fortunes_10))
                .service(web::resource("/all-fortunes").to_async(fortunes_all))
                .service(web::resource("/primes").to(primes)))

        })?
        .start();

    println!("listening on port 3000");
    sys.run()
}
