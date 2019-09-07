import path from 'path';
import { observable } from 'iaktta.preact';

export const appState = observable({
    selectedTest: ''
});

const ctx = require.context('../out', true, /\.json$/);
export let results: IConfiguration = {};
ctx.keys().forEach(k => {
    const tests = ctx(k);
    appState.selectedTest = Object.keys(tests)[0];
    results[path.basename(k, '.json')] = { tests };
});

interface IConfiguration {
    [key: string]: {
        tests: { [key: string]: ITestInfo };
    }
}

interface ITestInfo {
        "url": string;
        "requests": {
            "average": number;
            "mean": number;
            "stddev": number;
            "min": number;
            "max": number;
            "total": number;
            "p0_001": number;
            "p0_01": number;
            "p0_1": number;
            "p1": number;
            "p2_5": number;
            "p10": number;
            "p25": number;
            "p50": number;
            "p75": number;
            "p90": number;
            "p97_5": number;
            "p99": number;
            "p99_9": number;
            "p99_99": number;
            "p99_999": number;
            "sent": number;
        },
        "latency": {
            "average": number;
            "mean": number;
            "stddev": number;
            "min": number;
            "max": number;
            "p0_001": number;
            "p0_01": number;
            "p0_1": number;
            "p1": number;
            "p2_5": number;
            "p10": number;
            "p25": number;
            "p50": number;
            "p75": number;
            "p90": number;
            "p97_5": number;
            "p99": number;
            "p99_9": number;
            "p99_99": number;
            "p99_999": number;
        },
        "throughput": {
            "average": number;
            "mean": number;
            "stddev": number;
            "min": number;
            "max": number;
            "total": number;
            "p0_001": number;
            "p0_01": number;
            "p0_1": number;
            "p1": number;
            "p2_5": number;
            "p10": number;
            "p25": number;
            "p50": number;
            "p75": number;
            "p90": number;
            "p97_5": number;
            "p99": number;
            "p99_9": number;
            "p99_99": number;
            "p99_999": number;
        },
        "errors": number;
        "timeouts": number;
        "duration": number;
        "start":  string;
        "finish": string;
        "connections": number;
        "pipelining": number;
        "non2xx": number;
        "1xx": number;
        "2xx": number;
        "3xx": number;
        "4xx": number;
        "5xx": number;
        "mem_usage": number;
}