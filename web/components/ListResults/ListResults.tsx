import { h, Component } from 'preact';
import { observer, computed } from 'iaktta.preact';
import { results, appState, TestInfo } from '../../Results';
import * as css from './ListResults.css';

@observer
export class ListResults extends Component {
    @computed
    get items() {
        const testName = appState.selectedTest;
        const validResults = Object.entries(results).filter(([c, r]) => testName in r.tests);
        const maxRequests = validResults.reduce(
            (a, b) => Math.max(a, b[1].tests[testName]['2xx']), 0
        )
        const all = validResults.map(([name, cfg]) => {
            const pct = cfg.tests[testName]['2xx'] / maxRequests;
            return { name, pct, test: cfg.tests[testName] }
        });
        all.sort((a, b) => b.pct - a.pct);
        return all;
    }

    cpuUsage(row: TestInfo) {
        let total = 0, count = 0;
        for (const sample of row.samples) {
            if (!sample.precpu_stats) continue;
            const cpuusage = sample.cpu_stats.cpu_usage.total_usage - sample.precpu_stats.cpu_usage.total_usage;
            const sysusage = sample.cpu_stats.system_cpu_usage - sample.precpu_stats.system_cpu_usage;
            const dockerusage = (cpuusage / sysusage) * 100;
            total += dockerusage;
            count += 1;
        }
        return Math.round(total / count);
    }

    memUsage(row: TestInfo) {
        let total = 0, count = 0;
        for (const sample of row.samples) {
            total += sample.memory_stats.usage;
            count += 1;
        }
        return `${Math.round((total / count) / 1024768)} MB`;
    }

    xpuUsage(row: TestInfo) {
        return `${Math.floor(row.latency.p50)} ms`;
    }
    
    render() {
        let rows: any = [];
        for (const row of this.items) {
            const np = row.name.split('-');
            const mb = (row.test.mem_usage / 1024768) | 0;
            const pct = ((row.pct * 100) | 0);
            const errorCount = row.test.non2xx + row.test.errors;
            rows.push(
                <tr key={row.name} title={`${errorCount} requests returned errors`} className={errorCount ? css.error : ''}>
                    <td>{np[0]}</td>
                    <td>{np[1]}</td>
                    <td className={css.requests}>
                        <div className={css.bar}>
                            <div style={{ width: `${pct}%` }}></div>
                        </div>
                        <div className={css.requests_pct}>
                            {pct}%
                        </div>
                    </td>
                    <td style={{ justifyContent: 'flex-end' }}>{Math.floor(row.test.requests.total)}</td>
                    <td style={{ justifyContent: 'flex-end' }}>{this.memUsage(row.test)}</td>
                    <td style={{ justifyContent: 'flex-end' }}>{this.cpuUsage(row.test)}%</td>
                    <td style={{ justifyContent: 'flex-end' }}>{this.xpuUsage(row.test)}</td>
                </tr>
            )
        }

        return <div onClick={this.click} className={css.box}>
            <table className={css.table}>
                <thead>
                    <tr>
                        <th>language</th>
                        <th>framework</th>
                        <th>rank</th>
                        <th style={{ textAlign: 'right', justifyContent: 'flex-end' }}>req</th>
                        <th style={{ textAlign: 'right', justifyContent: 'flex-end' }}>avg memory usage</th>
                        <th style={{ textAlign: 'right', justifyContent: 'flex-end' }}>avg cpu usage</th>
                        <th style={{ textAlign: 'right', justifyContent: 'flex-end' }}>avg latency</th>
                    </tr>
                </thead>

                <tbody>
                    {rows}
                </tbody>
            </table>
        </div>;
    }
}