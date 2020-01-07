const throng = require('throng');
const os = require('os');
throng(os.cpus() * 3, () => require('./index.js'));
