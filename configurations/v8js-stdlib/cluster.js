const throng = require('throng');
const os = require('os');
throng(os.cpus(), () => require('./index.js'));
