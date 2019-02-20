process.env.AWS_XRAY_DEBUG_MODE=1;

const Consumer = require('queue').Consumer;
const Database = require('@subfuzion/database').Database;
const xray = require('aws-xray-sdk-core');

// set queue connection timeout to 0 since we want the worker queue
// consumer to block indefinitely while waiting for messages
let queueConfig = Consumer.createStdConfig({ timeout: 0 });
let databaseConfig = Database.createStdConfig();

let consumer, db, quitting = false;

// Set up signal handlers and open connections to database and queue.
async function init() {
  // Handle SIGTERM and SIGINT (ctrl-c) gracefully
  process.on('SIGTERM', async () => {
    console.log('worker received SIGTERM');
    // if already quitting then force quit
    if (quitting) {
      console.log('forcing quit now');
      process.exit();
    }
    await quit();
  });
  process.on('SIGINT', async () => {
    console.log('worker received SIGINT');
    // if already quitting then force quit
    if (quitting) {
      console.log('forcing quit now');
      process.exit();
    }
    await quit();
  });

  try {
    console.log('worker initializing');

    db = new Database(databaseConfig);
    await db.connect();
    console.log('connected to database');

    consumer = new Consumer('queue', queueConfig);
    consumer.on('error', err => {
      console.log(err.message);
      process.exit(1);
    });
    await new Promise(resolve => {
      consumer.on('ready', async() => {
        resolve();
      });
    });
    console.log('connected to queue');

    console.log('worker initialized');
  } catch (err) {
    console.log(err);
    process.exit(1);
  }
}

// Quit gracefully by closing queue and database connections first.
async function quit() {
  // don't try to handle quit twice (for example, after a SIGTERM,
  // quit will be started; once the queue processing loops breaks
  // because the consumer connection gets closed here, it will also
  // call quit.
  if (quitting) return;
  quitting = true;
  console.log('worker stopping');
  //if (consumer) await consumer.end(true)
  if (consumer) await consumer.quit();
  // consumer no longer receiving messages from the queue, wait a bit
  // for any writes to db to complete
  if (db) {
    setTimeout(async () => {
      if (db) await db.close();
      console.log('worker stopped');
      process.exit();
    }, 500);
  } else {
    console.log('worker stopped');
    process.exit();
  }
}

// main: start worker and run until signalled
(async () => {
  try {
    await init();
    console.log('worker processing queue');
    while (true) {
      try {
        let msg = await consumer.receive();
        if (!msg) continue;
        console.log('message received: ', msg);
        let json = JSON.parse(msg);
        let res = await db.updateVote(json);
        console.log('message saved: %j', res);

        let segment = xray.getSegment();

        if (segment)
          xray.getSegment().close();

      } catch (err) {
        console.log(err);
      }
    }
  } catch (err) {
    console.log(err);
  } finally {
    try {
      await quit();
      console.log('worker stopped processing queue');
    } catch (err) {
      console.log(err);
      process.exit(1);
    }
  }
})();
