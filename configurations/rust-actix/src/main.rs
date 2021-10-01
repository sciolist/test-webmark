use actix::prelude::*;
use actix_http::error::ErrorInternalServerError;
use actix_http::{HttpService, KeepAlive};
use actix_service::map_config;
use actix_web::dev::{AppConfig, Body, Server};
use actix_web::http::{StatusCode};
use actix_web::{web, App, Error, HttpServer, HttpResponse};
use actix_rt::net::{TcpListener};
use bytes::{Bytes};
use socket2::{Socket, Domain, Type};
use std::net::SocketAddr;

mod database;
use crate::database::{PgConnection, Fortunes10, FortunesAll};

async fn fortunes_all(db: web::Data<Addr<PgConnection>>) -> Result<HttpResponse, Error> {
    let res = db.send(FortunesAll).await.map_err(|e| ErrorInternalServerError(e))?;
    if let Ok(data) = res {
        let body = serde_json::to_string(&data).unwrap();
        Ok(HttpResponse::with_body(StatusCode::OK, Body::Bytes(Bytes::from(body))))
    } else {
        Ok(HttpResponse::InternalServerError().into())
    }
}

async fn fortunes_10(db: web::Data<Addr<PgConnection>>) -> Result<HttpResponse, Error> {
    let res = db.send(Fortunes10).await.map_err(|e| ErrorInternalServerError(e))?;
    if let Ok(data) = res {
        let body = serde_json::to_string(&data).unwrap();
        Ok(HttpResponse::with_body(StatusCode::OK, Body::Bytes(Bytes::from(body))))
    } else {
        Ok(HttpResponse::InternalServerError().into())
    }
}

async fn primes() -> HttpResponse {
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
    HttpResponse::with_body(
        StatusCode::OK,
        Body::Bytes(Bytes::from(list.join("\n"))),
    )
}

async fn helloworld() -> HttpResponse {
    HttpResponse::with_body(
        StatusCode::OK,
        Body::Bytes(Bytes::from_static(b"Hello, World!")),
    )
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    Server::build()
        .backlog(1024)
        .bind("app", "0.0.0.0:3000", move || {
            HttpService::build()
                .keep_alive(KeepAlive::Os)
                .client_timeout(0)
                .h1(map_config(
                    App::new()
                        .data_factory(|| PgConnection::connect())
                        .service(web::resource("/10-fortunes").to(fortunes_10))
                        .service(web::resource("/all-fortunes").to(fortunes_all))
                        .service(web::resource("/primes").to(primes))
                        .service(web::resource("/helloworld").to(helloworld)),
                    |_| AppConfig::default(),
                ))
                .tcp()
        })?
        .start()
        .await
}