const { Pool } = require('pg').native;
const http = require('http');
const os = require('os');

const pool = new Pool({
    max: Math.floor(500 / (os.cpus()))
});

const routes = {};
const HelloWorld = new Buffer('Hello, world!');
routes['/helloworld'] = async function (req, res) {
    res.end(HelloWorld);
}

const fortunes10 = { name: 'q10', text: 'select id, message from fortunes limit 10' };
routes['/10-fortunes'] = async function (req, res) {
    const result = await pool.query(fortunes10);
    res.end(JSON.stringify(result.rows));
}

const fortunesall = { name: 'qall', text: 'select id, message from fortunes' };
routes['/all-fortunes'] = async function (req, res) {
    const result = await pool.query(fortunesall);
    res.end(JSON.stringify(result.rows));
}

routes['/primes'] = async function (req, res) {
    let list = [];
    outer: for (let test = 2; test <= 10000; ++test) {
        for (let v = 2; v < test; ++v) {
            if (test % v === 0) continue outer;
        }
        list.push(test);
    }
    res.end(list.join('\n'));
}

routes['/404'] = async function (req, res) {
    res.statusCode = 404;
    res.end();
}

const server = http.createServer(function (req, res) {
    const route = routes[req.url] || routes['/404'];
    route(req, res).catch(function () {
        res.statusCode = 500;
        res.end();
    });
});
server.listen(3000);
