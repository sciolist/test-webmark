const runner = require('./run-configuration');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

if (!process.env.WEBMARK_DOCKER_ROOT) {
    process.env.WEBMARK_DOCKER_ROOT = __dirname;
}
if (!process.env.URL) {
    process.env.URL = "http://localhost:3000";
}
if (!process.env.DOCKER_API) {
    process.env.DOCKER_API = "unix:/var/run/docker.sock:";
}

if (!fs.existsSync('./out')) {
    fs.mkdirSync('./out');
}

let force = false;
let configurations = glob.sync('./configurations/*');
if (process.argv.length > 2) {
    force = true;
    configurations = process.argv.slice(2);
}

async function run() {
    for (const cfgPath of configurations) {
        const cfg = path.basename(cfgPath);
        if (!force && fs.existsSync(`./out/${cfg}.json`)) {
            console.log(`already ran ${cfg}`);
            continue;
        }

        console.log(`running ${cfg} tests`);
        await runner(cfg);
    }
}

run();