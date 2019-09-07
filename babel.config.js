module.exports = api => {
    api.cache(true);
    if (process.env.BACKEND) {
        return {
            presets: [
                ['@babel/env', { "targets": { "node": 12 } }],
                ['@babel/typescript', { "jsxPragma": "h" }]
            ],
            plugins: [
                '@babel/plugin-transform-runtime',
                ['@babel/plugin-proposal-decorators', { legacy: true }],
                ['@babel/plugin-proposal-class-properties', { loose: true }]
            ]
        };
    } else {
        return {
            presets: [
                ['@babel/env', { "targets": { "chrome": 74 } }],
                'babel-preset-preact',
                ['@babel/typescript', { "jsxPragma": "h" }]
            ],
            plugins: [
                '@babel/plugin-transform-runtime',
                ['@babel/plugin-proposal-decorators', { legacy: true }],
                ['@babel/plugin-proposal-class-properties', { loose: true }]
            ]
        };
    }
};
