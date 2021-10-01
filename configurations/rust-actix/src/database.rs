use std::env;
use std::io;
use actix::prelude::*;
use futures::{FutureExt, StreamExt};
use tokio_postgres::{connect, Client, NoTls, Statement};

use serde::{Serialize};

#[derive(Serialize)]
pub struct Fortune {
    pub id: i32,
    pub message: String,
}

/// Postgres interface
pub struct PgConnection {
    pub cl: Client,
    pub fortunes_10: Statement,
    pub fortunes_all: Statement,
}

impl Actor for PgConnection {
    type Context = Context<Self>;
}

impl PgConnection {
    pub async fn connect_pg() -> Result<Client, io::Error> {
        let (cl, conn) = connect("postgresql://postgres:webmark@webmarkdb:5432/postgres", NoTls)
            .await
            .expect("can not connect to postgresql");
        actix_rt::spawn(conn.map(|_| ()));
        Ok(cl)
    }

    pub async fn connect() -> Result<Addr<PgConnection>, io::Error> {
        let (cl, conn) = connect("postgresql://postgres:webmark@webmarkdb:5432/postgres", NoTls)
            .await
            .expect("can not connect to postgresql");
        actix_rt::spawn(conn.map(|_| ()));

        let fortunes_10 = cl.prepare("select id, message from fortunes limit 10").await.unwrap();
        let fortunes_all = cl.prepare("select id, message from fortunes").await.unwrap();

        Ok(PgConnection::create(move |_| PgConnection {
            cl,
            fortunes_10,
            fortunes_all,
        }))
    }
}

pub struct Fortunes10;

impl Message for Fortunes10 {
    type Result = io::Result<Vec<Fortune>>;
}

impl Handler<Fortunes10> for PgConnection {
    type Result = ResponseFuture<Result<Vec<Fortune>, io::Error>>;

    fn handle(&mut self, _: Fortunes10, _: &mut Self::Context) -> Self::Result {
        let mut items: Vec<Fortune> = Vec::with_capacity(10);
        let fut = self.cl.query_raw(&self.fortunes_10, &[]);
        Box::pin(async move {
            let mut stream = fut
                .await
                .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("{:?}", e)))?;

            while let Some(row) = stream.next().await {
                let row = row.map_err(|e| {
                    io::Error::new(io::ErrorKind::Other, format!("{:?}", e))
                })?;
                items.push(Fortune {
                    id: row.get(0),
                    message: row.get(1),
                });
            }
            
            Ok(items)
        })
    }
}

pub struct FortunesAll;

impl Message for FortunesAll {
    type Result = io::Result<Vec<Fortune>>;
}

impl Handler<FortunesAll> for PgConnection {
    type Result = ResponseFuture<Result<Vec<Fortune>, io::Error>>;

    fn handle(&mut self, _: FortunesAll, _: &mut Self::Context) -> Self::Result {
        let mut items: Vec<Fortune> = Vec::with_capacity(1000);
        let fut = self.cl.query_raw(&self.fortunes_all, &[]);
        Box::pin(async move {
            let mut stream = fut
                .await
                .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("{:?}", e)))?;

            while let Some(row) = stream.next().await {
                let row = row.map_err(|e| {
                    io::Error::new(io::ErrorKind::Other, format!("{:?}", e))
                })?;
                items.push(Fortune {
                    id: row.get(0),
                    message: row.get(1),
                });
            }
            
            Ok(items)
        })
    }
}