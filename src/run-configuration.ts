import { IDockerhost } from '../docker/pool';
import cp from 'child_process';
import fs from 'fs';
import got from 'got';
import autocannon from 'autocannon';
import { tests, connections, threads, duration } from './tests';

const sleep = ms => new Promise(s => setTimeout(s, ms));
async function waitForExit(proc, cfg) {
    return new Promise((res, rej) => proc.once('exit', (code, c) => {
        code ? rej(new Error(`${cfg} process failed with code ${code}`)) : res()
    }));
}

async function getStats(dh: IDockerhost, containerId: string) {
    let host = (dh.DOCKER_HOST || 'unix:/var/run/docker.sock').replace(/^tcp:/, 'http:');
    if (host.startsWith('unix:')) {
        host += ':';
    }
    const url = `${host}/containers/${containerId}/stats?stream=false`;
    const res = await got(url);
    return JSON.parse(res.body);
}

async function runTestIteration(host: IDockerhost, containerId: string, testName: string, testConfiguration: any) {
    let done = false;
    let mem_usage = -1;
    let samples = [];
    const instance = autocannon({
        url: `${host.URL}/${testName}`,
        timeout: duration * 3,
        connections: connections,
        threads: threads,
        duration: duration
    });
    autocannon.track(instance, {
        renderProgressBar: false,
        renderResultsTable: false,
        renderLatencyTable: false
    })
    instance.on('done', () => done = true);
    while (!done) {
        const stats = await getStats(host, containerId);
        mem_usage = Math.max(mem_usage, stats.memory_stats.usage);
        samples.push(stats);
        await sleep(250);
    }
    const output = await instance;
    return { ...output, samples, mem_usage };
}

async function startContainers(host: IDockerhost, configurationName: string) {
    const env = { ...process.env, ...host, CONFIGURATION: configurationName };
    let containerId = "-1";
    const proc = cp.execFile('sh', [__dirname + '/start-configuration.sh'], {
        cwd: __dirname,
        env
    });
    proc.stderr.pipe(process.stderr);
    proc.stdout.on('data', d => {
        const str = d.toString();
        if (/^CONTAINER=/.test(str)) {
            containerId = str.split('=')[1].trim();
        }
    });
    proc.stdout.pipe(process.stdout);
    await waitForExit(proc, configurationName);
    return containerId;
}

export async function run(configurationName, hostpool) {
    const host = await hostpool.acquire();
    try {
        console.log(`${configurationName} starting on ${host.URL}`);
        const containerId = await startContainers(host, configurationName);
        let results = {};
        for (const [testName, testConfig] of Object.entries(tests)) {
            console.log(`${configurationName}: test ${testName} is starting`);
            for (let i=0; i<2; ++i) {
                const result = await runTestIteration(host, containerId, testName, testConfig);
                results[testName] = result;
            }
            console.log(`${configurationName}: test ${testName} is ending`);
        }
        console.log(`${configurationName} ending`);
        fs.writeFileSync(`./out/${configurationName}.json`, JSON.stringify(results, null, 4));
    } finally {
        await hostpool.release(host);
    }
}
