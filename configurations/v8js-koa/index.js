const Koa = require('koa');
const KoaRouter = require('@koa/router');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: 'postgres://app:app@db/app' });
const router = new KoaRouter();

router.get('/helloworld', async ctx => {
    ctx.body = "Hello, world!"
});

router.get('/10-fortunes', async ctx => {
    const result = await pool.query('select id, message from fortunes limit 10');
    ctx.body = result.rows;
});

router.get('/all-fortunes', async ctx => {
    const result = await pool.query('select id, message from fortunes');
    ctx.body = result.rows;
});

router.get('/primes', async (ctx) => {
    let list = [];
    outer: for (let test = 2; test <= 10000; ++test) {
        for (let v = 2; v < test; ++v) {
            if (test % v === 0) continue outer;
        }
        list.push(test);
    }
    ctx.body = list.join('\n');
});

const app = new Koa();
app.use(router.routes());
app.listen(3000);

