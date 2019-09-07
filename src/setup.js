process.env.BACKEND = 1;
require('@babel/register')({
    cwd: require('path').resolve(__dirname, '..'),
    extensions: ['.ts', '.tsx'],
    rootMode: 'upward'
});

process.on('unhandledRejection', ex => {
    console.error(ex);
    process.exit(-2);
});
