use crate::errors::{Error};
use actix_web::web::Json;
use actix_web::{get, web, Responder};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;

#[derive(Serialize, Deserialize, Debug)]
pub struct Fortune {
    id: i32,
    message: String
}

#[get("/10-fortunes")]
pub async fn fortunes10(pool: web::Data<PgPool>) -> Result<impl Responder, Error> {
    let todos = sqlx::query_as!(Fortune, r#"select id, message from fortunes limit 10"#)
        .fetch_all(pool.get_ref())
        .await?;

    Ok(Json(todos))
}

#[get("/all-fortunes")]
pub async fn fortunesall(pool: web::Data<PgPool>) -> Result<impl Responder, Error> {
    let todos = sqlx::query_as!(Fortune, r#"select id, message from fortunes"#)
        .fetch_all(pool.get_ref())
        .await?;

    Ok(Json(todos))
}

#[get("/helloworld")]
pub async fn helloworld() -> impl Responder {
    "Hello world"
}


#[get("/primes")]
pub async fn cpu() -> Result<impl Responder, Error> {
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
    Ok(list.join("\n"))
}
