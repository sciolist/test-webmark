const throng = require('throng');
const os = require('os');
throng(os.cpus().length, () => require('./index.js'));
