import { h, Component } from 'preact';
import { observer, computed } from 'iaktta.preact';
import { results, appState } from '../../Results';
import * as css from './ListTests.css';
import { ListResults } from '../ListResults/ListResults';

@observer
export class ListTests extends Component {
    @computed
    get items() {
        const testName = '2.rm_todo'
        const maxRequests = Object.values(results).reduce(
            (a, b) => Math.max(a, b.tests[testName]['2xx']), 0
        )

        const all = Object.entries(results).map(([name, cfg]) => {
            const pct = cfg.tests[testName]['2xx'] / maxRequests;
            return { name, pct, test: cfg.tests['1.add_todo'] }
        });
        all.sort((a, b) => b.pct - a.pct);
        return all;
    }

    selectTest = testName => {
        appState.selectedTest = testName;
    };
    
    render() {
        const names = new Set(Object.values(results).flatMap(v => Object.keys(v.tests)));
        const tests = Array.from(names).map(t => {
            const active = t === appState.selectedTest;
            return <a className={`${css.test} ${active ? css.active : ''}`} onClick={() => this.selectTest(t)} key={t}>{t}</a>
        });

        return <div>
            <div className={css.tests}>{tests}</div>
            <div className={css.results}>
                <ListResults />
            </div>
        </div>;
    }
}