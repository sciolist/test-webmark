#[macro_use] extern crate nickel;
extern crate r2d2;
extern crate r2d2_postgres;
extern crate serde_json;
#[macro_use] extern crate serde_derive;
use std::env;
use postgres::{NoTls};
use nickel::Nickel;
use r2d2_postgres::PostgresConnectionManager;

#[derive(Clone, Debug, Serialize, Deserialize)]
struct Fortune {
    id : i32,
    message : String,
}

fn main() {
    let database_url = env::var("PGCONNSTRING").expect("PGCONNSTRING missing");
    let manager = PostgresConnectionManager::new(
        database_url.parse().unwrap(),
        NoTls,
    );
    let pool = r2d2::Pool::new(manager).unwrap();
    let q1 = pool.clone();
    let q2 = pool.clone();

    let mut server = Nickel::new();
    server.utilize(router! {
        get "/10-fortunes" => |_req, _res| {
            let mut result: Vec<Fortune> = Vec::new();
            let mut client = q1.get().unwrap();
            for row in &client.query("SELECT id, message FROM fortunes LIMIT 10", &[]).unwrap() {
                result.push(Fortune { id: row.get(0), message: row.get(1) });
            }
            serde_json::to_string(&result).unwrap()
        }
        get "/primes" => |_req, _res| {
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
        get "/helloworld" => |_req, _res| {
            "Hello, world!"
        }
        get "/all-fortunes" => |_req, _res| {
            let mut result: Vec<Fortune> = Vec::new();
            let mut client = q2.get().unwrap();
            for row in &client.query("SELECT id, message FROM fortunes", &[]).unwrap() {
                result.push(Fortune { id: row.get(0), message: row.get(1) });
            }
            serde_json::to_string(&result).unwrap()
        }
    });

    server.listen("0.0.0.0:3000").unwrap();
}

