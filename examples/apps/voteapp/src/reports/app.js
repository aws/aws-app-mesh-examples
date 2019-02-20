process.env.AWS_XRAY_DEBUG_MODE=1;

const axios = require('axios');
const express= require('express');
const http = require('http');
const morgan = require('morgan');

const port = process.env.PORT || 3000;
const app = express();
const server = http.createServer(app);

const xray = require('aws-xray-sdk-core');
const xrayExpress = require('aws-xray-sdk-express');
xray.middleware.disableCentralizedSampling();

const captureAxios = require('./xray-axios');

let ax = axios.create({
    baseURL: process.env.DATABASE_PROXY_URI || 'http://database-proxy:3000/'
});

captureAxios(ax);

// install route logging middleware
app.use(morgan('dev'));

// install json body parsing middleware
app.use(express.json());

// install x-ray tracing
app.use(xrayExpress.openSegment('reports.app'));

// root route handler
app.get('/', (_, res) => {
  return res.send({ success: true, result: 'hello'});
});

// results route handler
app.get('/results', async (_, res) => {
  try {
    console.log('GET /results');
    let result = await ax.get('/results');
    let data = result.data;
    // ex: { success: true, result: { a: X, b: X } }
    console.log('data: ', data);

    // append version 2 extra field
    if (process.env.VERSION && process.env.VERSION.startsWith("2")) {
      console.log(`version: ${process.env.VERSION}`)
      let r = data.result; 
      console.log(`data: ${r}`)
      r.totalVotes = r.a + r.b;
      r.version = "2.0"
    // ex: { success: true, result: { a: X, b: X, totalVotes: X } }
      console.log(`v2 data: ${r}`)
    }

    res.send(data);
  } catch (err) {
    console.log('ERROR: GET /results: %s', err.message || err.response || err);
    res.status(500).send({ success: false, reason: 'internal error' });
  }
});

app.use(xrayExpress.closeSegment());

// initialize and start running
(async () => {
  try {
    await new Promise(resolve => {
      server.listen(port, () => {
        console.log(`listening on port ${port}`);
        resolve();
      });
    });
  
  } catch (err) {
    console.log(err);
    process.exit(1);
  }
})();
