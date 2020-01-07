import { IDockerhost } from '../docker/pool';
import got from 'got';
import autocannon from 'autocannon';
import { tests, connections, threads, duration } from './tests';

const sleep = ms => new Promise(s => setTimeout(s, ms));

async function getStats(dh: IDockerhost, containerId: string) {
    let host = (dh.DOCKER_HOST || 'unix:/var/run/docker.sock').replace(/^tcp:/, 'http:');
    if (host.startsWith('unix:')) {
        host += ':';
    }
    const url = `${host}/containers/${containerId}/stats?stream=false`;
    const res = await got(url);
    return JSON.parse(res.body);
}

async function runTestIteration(pass: number, host: IDockerhost, containerId: string, testName: string, testConfiguration: any) {
    let done = false;
    let mem_usage = -1;
    let samples = [];
    const instance = autocannon({
        url: `${host.URL}/${testName}`,
        timeout: duration * 3,
        connections: connections,
        threads: threads,
        pipelining: 10,
        duration: pass === 0 ? 3 : duration
    });
    autocannon.track(instance, {
        renderProgressBar: true,
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

export async function *run(containerId, configurationName, host: IDockerhost) {
    console.log(`${configurationName} starting on ${host.URL}`);
    let results = {};
    for (const [testName, testConfig] of Object.entries(tests)) {
        console.log(`${configurationName}: test ${testName} is starting`);
        let data = {};
        for (let i=0; i<2; ++i) {
            data = await runTestIteration(i, host, containerId, testName, testConfig);
        }
        yield { testName, data };
        console.log(`${configurationName}: test ${testName} is ending`);
    }
    console.log(`${configurationName} ending`);
    return results;
}
