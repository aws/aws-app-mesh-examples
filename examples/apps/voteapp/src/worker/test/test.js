const assert = require('assert');
const Database = require('@subfuzion/database').Database;
const Producer = require('@subfuzion/queue').Producer;

suite('queue tests', () => {
  // redis configuration
  let queueConfig = Producer.createStdConfig();
  let producer;

  // database configuration
  let dbConfig = Database.createStdConfig();
  let db;

  // let db;

  // open connections
  before(async () => {
    // connect to db
    db = new Database(dbConfig);
    await db.connect();

    // connect to queue
    producer = new Producer('queue', queueConfig);
  });

  // close connections
  after(async () => {
    // disconnect from queue
    await producer.quit();

    // drop test database and disconnect
    await db.instance.dropDatabase();
    await db.close();
  });

  test('ping queue', async() => {
    let resp = await producer.ping();
    assert.equal(resp, 'PONG');
  });

  suite('send votes to queue', () => {
    let votes_a = 3;
    let votes_b = 2;

    let votes = [];
    for (let i = 0; i < votes_a; i++) {
      votes.push({ vote: 'a' });
    }
    for (let i = 0; i < votes_b; i++) {
      votes.push({ vote: 'b' });
    }

    before(async function() {
      this.timeout(15 * 1000);

      votes.forEach(async v => {
        await producer.send(v);
      });

      // pause a bit to give the worker process time to
      // process the queue before we run database queries
      await pause(2 * 1000, 'let the worker process the queue before querying the database');
    });

    test('tally votes', async() => {
      let tally = await db.tallyVotes();
      assert.ok(tally);
      assert.equal(tally.a, votes_a, `'a' => expected: ${votes_a}, actual: ${tally.a}`);
      assert.equal(tally.b, votes_b, `'b' => expected: ${votes_b}, actual: ${tally.b}`);
    });

  });

});

async function pause(ms, reason) {
  return new Promise(resolve => {
    console.warn(`pausing for ${ms} ms...${reason}`);
    setTimeout(resolve, ms);
  });
}