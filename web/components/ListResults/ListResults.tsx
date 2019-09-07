import { h, Component } from 'preact';
import { observer, computed } from 'iaktta.preact';
import { results, appState } from '../../Results';
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
    
    render() {
        let rows: any = [];
        for (const row of this.items) {
            const np = row.name.split('-');
            const mb = (row.test.mem_usage / 1024768) | 0;
            const pct = (row.pct * 100) | 0;
            const hasError = row.test.non2xx > 0;
            rows.push(
                <tr key={row.name} className={hasError ? css.error : ''}>
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
                    <td style={{ textAlign: 'right' }}>{Math.floor(row.test["2xx"] / row.test.duration)}</td>
                    <td style={{ textAlign: 'right' }}>{mb} MB</td>
                </tr>
            )
        }

        return <div onClick={this.click} className={css.box}>
            <table className={css.table}>
                <thead>
                    <tr>
                        <th>language</th>
                        <th>framework</th>
                        <th colSpan={2}>requests per second</th>
                        <th style={{ textAlign: 'right' }}>max memory usage</th>
                    </tr>
                </thead>

                <tbody>
                    {rows}
                </tbody>
            </table>
        </div>;
    }
}