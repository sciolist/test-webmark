const { Pool } = require('pg').native;
const http = require('http');

const pool = new Pool({
    connectionString: 'postgresql://postgres:webmark@webmarkdb:5432/postgres',
    max: 150
});

const HelloWorld = Buffer.from('Hello, world!');
function helloworldHandler(res) {
    res.end(HelloWorld);
}

const fortunes10 = { name: 'q10', text: 'select id, message from fortunes limit 10' };
async function fortunes10Handler(res) {
    let r = await pool.query(fortunes10);
    res.end(JSON.stringify(r.rows));
}

const fortunesall = { name: 'qall', text: 'select id, message from fortunes' };
async function fortunesAllHandler(res) {
    let r = await pool.query(fortunesall);
    res.end(JSON.stringify(r.rows));
}

function primesHandler(res) {
    let list = [];
    outer: for (let test = 2; test <= 10000; ++test) {
        for (let v = 2; v < test; ++v) {
            if (test % v === 0) continue outer;
        }
        list.push(test);
    }
    res.end(list.join('\n'));
}

const server = http.createServer(function (req, res) {
    switch (req.url) {
        case '/10-fortunes': return fortunes10Handler(res);
        case '/all-fortunes': return fortunesAllHandler(res);
        case '/primes': return primesHandler(res);
        case '/helloworld': return helloworldHandler(res);
        default: return res.end();
    }
});
server.listen(3000);
