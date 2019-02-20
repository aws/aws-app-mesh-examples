const assert = require('assert');
const Consumer = require('../lib/Consumer');
const Producer = require('../lib/Producer');
const Queue = require('../lib/Queue');
const Redis = require('ioredis');

const topic = 'queue';

suite('queue tests', () => {
  // Create a standard config and override db
  // (a standard config overrides defaults with values from the environment and finally any explicit values)
  let config = Queue.createStdConfig();
  let opts = {};

  suite('basic redis tests', () => {
    // redis client
    let r;

    setup(() => {
      r = new Redis(config);
    });

    teardown(async () => {
      // make sure to tell redis to close connections or mocha won't exit
      await r.quit();
    });

    test('ping redis', async () => {
      let res = await r.ping();
      assert.equal(res, 'PONG');
    });

    test('retrieve messages from redis queue in fifo order', async () => {
      let key = topic;
      let vals = [ 'a', 'b', 'c' ];
      await r.rpush(key, ...vals);

      // check results received in same order sent
      vals.forEach(async v => {
        let result = await r.blpop(key, 1);
        // result is an array [ list, value ], e.g., [ "queue", "a" ]
        // console.log(`${result[1]} should equal ${v}`)
        assert.equal(result[1], v);
      });
    });

  }); // basic redis tests

  suite('producer-consumer tests', () => {
    /*eslint no-unused-vars: "off"*/
    let ctx;
    // save the mocha context before each test
    // note that this can't be done using an arrow function
    beforeEach(function() {
      ctx = this;
    });

    test('new connection successfully pings', async () => {
      let conn = new Queue(topic, config, opts);
      let res = await conn.ping();
      assert.equal(res, 'PONG');
      await conn.quit();
    });

    test('using connection after quit throws an error', async () => {
      let conn = new Queue(topic, config, opts);
      await conn.quit();
      try {
        await conn.ping();
        throw new Error('expected ping after quit to fail');
      } catch (err) {
        let expected = 'Connection is closed.';
        assert.equal(err.message, expected);
      }
    });

    test('send and receive messages using producer and consumer', async () => {
      let p = new Producer(topic, config, opts);
      let c = new Consumer(topic, config, opts);
      let vals = [ 'a', 'b', 'c' ];
      vals.forEach(async v => {
        await p.send(v);
      });

      // check results received in same order sent
      vals.forEach(async v => {
        let result = await c.receive();
        assert.equal(result, v);
      });

      await p.quit();
      await c.quit();
    });

    test('can quit waiting consumer', async () => {
      let c = new Consumer(topic, config, opts);

      // wait 200 ms and then close the connection
      setTimeout(async () => {
        await c.quit();
      }, 500);

      // blocking wait should return with null as soon as conn is closed when timer fires
      let result = await c.receive(1);
      assert.equal(result, null);
    });

    test('consumer should block until it receives a message', async function() {
      this.timeout(4000);
      let c = new Consumer(topic, config, opts);

      // wait 200 ms and then close the connection
      setTimeout(async () => {
        let p = new Producer(topic, config, opts);
        await p.send('foo');
        await p.quit();
      }, 2500);

      // blocking wait should return with null as soon as conn is closed when timer fires
      let result = await c.receive(3);
      assert.equal(result, 'foo');
      await c.quit();
    });

  }); // producer-consumer tests

}); // queue tests

