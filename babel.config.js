module.exports = api => {
    api.cache(true);
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
};
