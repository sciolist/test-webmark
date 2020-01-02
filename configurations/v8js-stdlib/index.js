const { Pool } = require('pg').native;
const http = require('http');
const os = require('os');

const pool = new Pool({
	max: Math.floor(500 / (os.cpus() * 3))
});

const routes = {};
routes['/helloworld'] = async function (req, res) {
    res.end('Hello, world!');
}

routes['/10-fortunes'] = async function (req, res) {
    const result = await pool.query({ name: 'q10', text: 'select id, message from fortunes limit 10' });
    res.end(JSON.stringify(result.rows));
}

routes['/all-fortunes'] = async function (req, res) {
    const result = await pool.query({ name: 'qall', text: 'select id, message from fortunes' });
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

http.createServer(function (req, res) {
    const route = routes[req.url] || routes['/404'];
    route(req, res).catch(function () {
        res.statusCode = 500;
        res.end();
    });
}).listen(3000);
