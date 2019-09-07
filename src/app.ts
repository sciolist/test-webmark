import { run } from './run-configuration';
import fs from 'fs';
import glob from 'glob';
import path from 'path';
import config from '../config.js';
const dockercfg = require(`../docker/${config.docker.type}`);

if (!fs.existsSync('./out')) {
    fs.mkdirSync('./out');
}

let configurations = [];
if (process.argv.length > 2) {
    configurations = process.argv.slice(2).map(p => path.basename(p));
} else {
    let allcfg = glob
        .sync(path.resolve(__dirname, '../configurations/*'))
        .map(p => path.basename(p));
    for (const cfg of allcfg) {
        if (fs.existsSync(`./out/${cfg}.json`)) {
            console.log(`already ran ${cfg}, skipping`);
            continue;
        }
        configurations.push(cfg);
    }
}

console.log('running configurations: ', configurations.join(', '));
async function main() {
    const pool = await dockercfg.startup(config.docker);
    try {
        await Promise.all(configurations.map(cfg => run(cfg, pool)));
    } finally {
        await pool.drain();
        await pool.clear();
        await dockercfg.shutdown(config.docker);
    }
    console.log('finished');
}
main();
