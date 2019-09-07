const cp = require('child_process');
const fs = require('fs');
const path = require('path');
const glob = require('glob');
const got = require('got');

const sleep = ms => new Promise(s => setTimeout(s, ms));
async function waitForExit(proc) {
    return new Promise((res, rej) => proc.once('exit', (code, c) => {
        c ? rej(new Error(c)) : res()
    }));
}

module.exports = async function run(CONFIGURATION) {
    const CONNECTIONS = 20;
    const THREADS = 10;
    const DURATION = 5;

    process.env.CONFIGURATION = CONFIGURATION;
    process.env.PATH = `${path.resolve('./node_modules/.bin')}:${process.env.PATH}`;
    process.env.ACOPTS=`--connections ${CONNECTIONS} --threads ${THREADS} --duration ${DURATION} --latency --json`;
    process.env.WARMUP_ACOPTS=`--connections ${CONNECTIONS} --threads ${THREADS} --duration 5 --latency --json`;

    let containerId = -1;
    const proc = cp.execFile('sh', ['start-configuration.sh']);
    
    proc.stderr.pipe(process.stderr);
    proc.stdout.on('data', d => {
        const str = d.toString();
        if (/^CONTAINER=/.test(str)) {
            containerId = str.split('=')[1].trim();
        }
    });
    proc.stdout.pipe(process.stdout);
    await waitForExit(proc);

    const testFiles = glob.sync('./tests/*');

    async function getStats() {
        const url = `unix:/var/run/docker.sock:/containers/${containerId}/stats?stream=false`;
        const res = await got(url);
        return JSON.parse(res.body);
    }

    cp.spawnSync('bash', [testFiles[0]], {
        env: { ...process.env, 'ACOPTS': process.env.WARMUP_ACOPTS }
    });
    let results = {};
    for (const t of testFiles) {
        const name = path.basename(t, '.sh');
        let running = true;
        let output = [];
        const proc = cp.spawn('bash', [t]);
        proc.stdout.on('data', d => output.push(d));
        proc.on('exit', () => running = false);
        let mem_usage = 0;
        while (running) {
            const stats = await getStats();
            mem_usage = Math.max(mem_usage, stats.memory_stats.usage);
            await sleep(250);
        }
        if (!/^_/.test(name)) {
            results[name] = {
                ...JSON.parse(Buffer.concat(output).toString()),
                mem_usage
            };
        }
    }
    fs.writeFileSync(`./out/${CONFIGURATION}.json`, JSON.stringify(results, null, 4));
}
