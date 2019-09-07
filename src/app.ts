import { run } from "./run-configuration";
import fs from "fs";
import glob from "glob";
import path from "path";
import config from "../config.js";
import { setupDatabase } from './database';
const dockercfg = require(`../docker/${config.docker.type}`);
const DIR = process.env.DIRECTORY = path.resolve(__dirname, '..', config.outputPath || 'out');

if (!fs.existsSync(DIR)) {
  fs.mkdirSync(DIR);
}

let configurations = [];
if (process.argv.length > 2) {
  configurations = process.argv.slice(2).map(p => path.basename(p));
} else {
  let allcfg = glob
    .sync(path.resolve(__dirname, "../configurations/*"))
    .map(p => path.basename(p));
  for (const cfg of allcfg) {
    if (fs.existsSync(`${DIR}/${cfg}.json`)) {
      console.log(`already ran ${cfg}, skipping`);
      continue;
    }
    configurations.push(cfg);
  }
}

console.log("running configurations: ", configurations.join(", "));
async function main() {
  const pool = await dockercfg.startup(config.docker);
  try {
    await Promise.all(configurations.map(async cfg => {
            const host = await pool.acquire();
            await setupDatabase(host);
            try {
                const data = await run(cfg, host);
                fs.writeFileSync(`${config.outputPath}/${cfg}.json`, JSON.stringify(data, null, 4));
            } finally {
                await pool.release(host);
            }
        }));
    } finally {
        await pool.drain();
        await pool.clear();
        await dockercfg.shutdown(config.docker);
    }
}

main();
