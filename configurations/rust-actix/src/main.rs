#[macro_use]
extern crate log;
mod errors;
mod services;

use actix_web::{web, App, HttpServer};
use actix_http::{KeepAlive};
use anyhow::Result;
use listenfd::ListenFd;
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::env;

#[actix_web::main]
async fn main() -> Result<()> {
    env_logger::init();

    let mut listenfd = ListenFd::from_env();

    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL is not set");
    let host = env::var("HOST").unwrap_or("0.0.0.0".to_owned());
    let port: u16 = env::var("PORT")
        .unwrap_or("3000".to_owned())
        .parse()
        .expect("PORT needs to be in 0-65535 range");

    let pool = PgPoolOptions::new()
        .max_connections(0x80)
        .connect(&database_url)
        .await
        .unwrap();

    let mut server = HttpServer::new(move || {
        App::new()
            .data(pool.clone())
            .service(crate::services::webmark::cpu)
            .service(crate::services::webmark::fortunes10)
            .service(crate::services::webmark::fortunesall)
            .service(crate::services::webmark::helloworld)
    });

    server = match listenfd.take_tcp_listener(0)? {
        Some(listener) => server.listen(listener)?,
        None => server.bind(format!("{}:{}", host, port))?,
    };

    info!("Starting server");
    server
        .backlog(1024)
        .keep_alive(KeepAlive::Os)
        .run()
        .await?;

    Ok(())
}
