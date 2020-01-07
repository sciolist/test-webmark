import { IDockerhost } from '../docker/pool';
import { run } from "./run-configuration";
import fs, { promises as fsp } from "fs";
import glob from "glob";
import path from "path";
import config from "../config.js";
import cp from 'child_process';
import { setupDatabase } from './database';
import { tests } from './tests';
const dockercfg = require(`../docker/${config.docker.type}`);
const DIR = process.env.DIRECTORY = path.resolve(__dirname, '..', config.outputPath || 'out');

if (!fs.existsSync(DIR)) {
  fs.mkdirSync(DIR);
}

const allConfigurations = glob
  .sync(path.resolve(__dirname, "../configurations/*"))
  .map(p => path.basename(p));

let configurations = [];
if (process.argv.length > 2) {
  configurations = process.argv.slice(2).map(p => path.basename(p));
} else {
  const allTests = Object.keys(tests);
  for (const cfg of allConfigurations) {
    const missing = allTests.find(t => !fs.existsSync(`${DIR}/${t}/${cfg}.json`));
    if (missing) configurations.push(cfg);
  }
}

async function startContainers(host: IDockerhost, configurationName: string) {
  const env = {
      ...process.env,
      ...host,
      ...(host.database || {}),
      CONFIGURATION: configurationName
  };
  let containerId = "-1";
  const startupFile = path.resolve(__dirname, 'start-configuration.sh');
  const proc = cp.execFile('sh', [startupFile], { cwd: __dirname, env });
  proc.stderr.pipe(process.stderr);
  proc.stdout.on('data', d => {
      const str = d.toString();
      if (/^CONTAINER=/.test(str)) {
          containerId = str.split('=')[1].trim();
      }
  });
  proc.stdout.pipe(process.stdout);
  await new Promise((resolve, reject) => {
    proc.once('exit', code => code ? reject(new Error(`${configurationName} failed with code ${code}`)) : resolve())
  });
  return containerId;
}

console.log("running configurations: ", configurations.join(", "));
async function main() {
  const pool = await dockercfg.startup(config.docker);
  try {
    for (const cfg of configurations) {
      const host = await pool.acquire();
      await setupDatabase(host);
      const containerId = await startContainers(host, cfg);
      try {
          for await (const result of run(containerId, cfg, host)) {
            await fsp.mkdir(`${config.outputPath}/${result.testName}`, { recursive: true });
            await fsp.writeFile(`${config.outputPath}/${result.testName}/${cfg}.json`, JSON.stringify(result.data, null, 4));
          }
      } finally {
        console.log('release');
          await pool.release(host);
      }
    }
  } finally {
      await pool.drain();
      await pool.clear();
      await dockercfg.shutdown(config.docker);
  }
}

main();
