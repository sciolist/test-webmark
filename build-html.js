const fs = require('fs');
const path = require('path');

const wrapper = (props) => `<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <title>webmark results</title>
        <style>
            body { color: #dbdbdb; background: #202b38; max-width: 1024px; margin: 32px auto 96px; font-family: system-ui, sans-serif; }
            table { width: 100%; border: 3px inset #ccc; border-collapse: collapse; }
            thead { background: teal; }
            th, td { border: 1px inset #ccc; text-align: left; padding: 8px; }
            .errors { background: rgba(255, 0, 0, 0.2); }
            .perf { background: orange; height: 16px; }
            .configs { display: grid; grid-template-columns: 1fr 1fr 1fr; margin-bottom: 24px; gap: 8px; }
            td.num { text-align: right; font-family: Menlo, monospace; }
            h1 { text-transform: capitalize; }
        </style>
    </head>
    <body>

    <div class="configs">
    ${props.allcfgs.map(cfg => `
        <label><input type="checkbox" checked onchange="document.body.classList.toggle('hide-'+this.id,!this.checked)" id="${cfg}" /> ${cfg}</label>
        <style>.hide-${cfg} .${cfg} { display: none; }</style>
    `).join('')}
    </div>

${props.html}
    </body>
</html>
`

const k = v => {
    if (v < 10000) return `${v|0}`;
    return `${(v/1000)|0}k`;
}

const template = (props) => `
<h1>${escape(props.test)}</h1>
<table>
    <thead>
        <tr>
            <th colspan="2" style="width: 20%">Configuration</th>
            <th colspan="2" style="width: 50%">TPS</th>
            <th style="width: 10%">Errors</th>
            <th style="width: 10%">99%<br />Latency</th>
            <th style="width: 10%">99.99%<br />Latency</th>
            <th style="width: 10%">Memory</th>
        </tr>
    </thead>
    <tbody>
    ${props.configurations.map(cfg => {
        return `<tr class="${cfg.configuration} ${cfg.main.errors > 0 ? 'errors' : ''}">
            <th>${cfg.configuration.split('-')[0]}</th>
            <th>${cfg.configuration.split('-')[1]}</th>
            <td style="width: 40%;"><div class="perf" style="width:${Math.round(cfg.pct*100)}%"></div></td>
            <td class="num">${k(cfg.main['2xx']/30)}</td>
            <td class="num">${cfg.main.errors}</td>
            <td class="num">${cfg.main.latency.p99}ms</td>
            <td class="num">${cfg.main.latency.p99_99}ms</td>
            <td class="num">${cfg.memory}MB</td>
        </tr>`
    }).join('')}
    </tbody>
</table>
`;

const tests = fs.readFileSync(path.resolve(__dirname, 'tests'), 'utf8').split(/\n/);
const html = [];

const parseMem = mem => {
    const v = mem.substring(0, mem.indexOf(' ')).toLowerCase();
    const num = Number(v.replace(/[^0-9\.]/ig, ''));
    return Math.round(num * (v.indexOf('gib') > -1 ? 1000 : 1));
}

for (const test of tests) {
    const testPath = path.resolve(__dirname, 'out', test);
    if (!fs.existsSync(testPath)) continue;
    const configurationNames = fs.readdirSync(testPath);
    if (!configurationNames.length) continue;
    const cfg = configurationNames.map(configuration => {
        let result;
        try {
            const lines = fs.readFileSync(path.resolve(testPath, configuration), 'utf8');
            result = lines.split(/\n/).filter(v => v.trim()).map(JSON.parse);
        } catch(ex) {
            return null;
        }
        const stats = result.filter(r => !r.url);
        return {
            configuration: path.basename(configuration, '.json'),
            memory: stats.map(s => parseMem(s.MemUsage)).sort((a, b) => b - a)[0],
            main: result.find(r => r.url)
        };
    }).filter(v => v);
    if (!cfg.length) continue;
    cfg.sort((a, b) => b.main['2xx'] - a.main['2xx']);
    cfg[0].pct = 1;
    for (let i=1; i<cfg.length; ++i) {
        cfg[i].pct = cfg[i].main['2xx'] / cfg[0].main['2xx']
    }
    html.push(template({ test, configurations: cfg }));
}

const allcfgs = fs
    .readdirSync(path.resolve(__dirname, 'configurations'))
    .filter(c => fs.statSync(path.resolve(__dirname, 'configurations', c)).isDirectory());

//const htmlPath = path.resolve(__dirname, 'result.html');
console.log(wrapper({ allcfgs, html: html.join('') }));
