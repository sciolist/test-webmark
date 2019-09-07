use std::io;
use actix::fut;
use actix::prelude::*;
use futures::{Future, Stream};
use tokio_postgres::{connect, Client, NoTls, Statement};

#[derive(Serialize, Debug)]
pub struct Fortune {
    pub id: i32,
    pub message: String,
}

pub struct PgConnection {
    cl: Option<Client>,
    fortunes_10: Option<Statement>,
    fortunes_all: Option<Statement>
}

impl Actor for PgConnection {
    type Context = Context<Self>;
}

impl PgConnection {
    pub fn connect(db_url: &str) -> Addr<PgConnection> {
        let hs = connect(db_url, NoTls);

        PgConnection::create(move |ctx| {
            let act = PgConnection {
                cl: None,
                fortunes_10: None,
                fortunes_all: None,
            };

            hs  .map_err(|_| panic!("can not connect to postgresql"))
                .into_actor(&act)
                .and_then(|(mut cl, conn), act, ctx| {
                    
                    ctx.wait(
                        cl.prepare("select id, message from fortunes limit 10")
                            .map_err(|_| ())
                            .into_actor(act)
                            .and_then(|st, act, _| {
                                act.fortunes_10 = Some(st);
                                fut::ok(())
                            }),
                    );
                    
                    ctx.wait(
                        cl.prepare("select id, message from fortunes")
                            .map_err(|_| ())
                            .into_actor(act)
                            .and_then(|st, act, _| {
                                act.fortunes_all = Some(st);
                                fut::ok(())
                            }),
                    );
                    
                    act.cl = Some(cl);
                    Arbiter::spawn(conn.map_err(|e| panic!("{}", e)));
                    fut::ok(())
                })
                .wait(ctx);
            act
        })
    }
}

pub struct Fortunes10;

impl Message for Fortunes10 {
    type Result = io::Result<Vec<Fortune>>;
}

impl Handler<Fortunes10> for PgConnection {
    type Result = ResponseFuture<Vec<Fortune>, io::Error>;

    fn handle(&mut self, _: Fortunes10, _: &mut Self::Context) -> Self::Result {
        let items: Vec<Fortune> = vec![];

        Box::new(
            self.cl
                .as_mut()
                .unwrap()
                .query(self.fortunes_10.as_ref().unwrap(), &[])
                .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("{:?}", e)))
                .fold(items, move |mut items, row| {
                    items.push(Fortune { id: row.get(0), message: row.get(1) });
                    Ok::<_, io::Error>(items)
                })
                .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("{:?}", e)))
                .map(|mut items| {
                    items.sort_by(|it, next| it.message.cmp(&next.message));
                    items
                }),
        )
    }
}

pub struct FortunesAll;

impl Message for FortunesAll {
    type Result = io::Result<Vec<Fortune>>;
}

impl Handler<FortunesAll> for PgConnection {
    type Result = ResponseFuture<Vec<Fortune>, io::Error>;

    fn handle(&mut self, _: FortunesAll, _: &mut Self::Context) -> Self::Result {
        let items: Vec<Fortune> = vec![];

        Box::new(
            self.cl
                .as_mut()
                .unwrap()
                .query(self.fortunes_all.as_ref().unwrap(), &[])
                .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("{:?}", e)))
                .fold(items, move |mut items, row| {
                    items.push(Fortune { id: row.get(0), message: row.get(1) });
                    Ok::<_, io::Error>(items)
                })
                .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("{:?}", e)))
                .map(|mut items| {
                    items.sort_by(|it, next| it.message.cmp(&next.message));
                    items
                }),
        )
    }
}
