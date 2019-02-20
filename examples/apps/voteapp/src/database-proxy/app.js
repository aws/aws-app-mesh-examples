const Database = require('@subfuzion/database').Database;
const express= require('express');
const http = require('http');
const morgan = require('morgan');

const xray = require('aws-xray-sdk-core');
const xrayExpress = require('aws-xray-sdk-express');
xray.middleware.disableCentralizedSampling();

const port = process.env.PORT || 3000;
const app = express();
const server = http.createServer(app);

let databaseConfig = Database.createStdConfig();
let db;

// install route logging middleware
app.use(morgan('dev'));

// install json body parsing middleware
app.use(express.json());

// install x-ray tracing
app.use(xrayExpress.openSegment('database-proxy.app'));

// root route handler
app.get('/', (_, res) => {
  return res.send({ success: true, result: 'hello'});
});

// vote route handler
app.post('/vote', async (req, res) => {
  try {
    console.log('POST /vote: %j', req.body);
    let v = req.body;
    let result = await db.updateVote(v);
    console.log('stored :', result);
    res.send({ success: true, result: {
      voter_id: result.voter_id,
      vote: result.vote
    }});
  } catch (err) {
    console.log('ERROR: POST /vote: %j', err);
    res.send(500, { success: false, reason: err.message });
  }
});

// results route handler
app.get('/results', async (req, res) => {
  try {
    console.log('GET /results');
    let result = await db.tallyVotes();
    console.log('results: %j', result);
    res.send({ success: true, result: result });
  } catch (err) {
    console.log('ERROR GET /results: %j', err);
    res.send(500, { success: false, reason: err.message });
  }
});

app.use(xrayExpress.closeSegment());

// initialize and start running
(async () => {
  try {
    // initialize database client for querying vote results
    db = new Database(databaseConfig);
    console.log(`connecting to database at (${db.connectionURL})`);
    await db.connect();
    console.log(`connected to database (${db.connectionURL})`);
    server.listen(port, () => console.log(`listening on port ${port}`));
  } catch (err) {
    console.log(err);
    process.exit(1);
  }
})();
