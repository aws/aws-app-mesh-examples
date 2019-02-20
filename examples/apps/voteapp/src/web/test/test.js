const assert = require('assert');
const axios = require('axios');
const Database = require('@subfuzion/database').Database;

suite('vote tests', () => {
  let voteAPI = axios.create({
    baseURL: 'http://web:3000/'
  });

  let votes_a = 3;
  let votes_b = 2;

  before(async function() {
    this.timeout(10 * 1000);

//    await pause(2 * 1000, 'wait for environment to be stable');

    // initialize test votes
    let votes = [];
    for (let i = 0; i < votes_a; i++) {
      votes.push({ vote: 'a' });
    }
    for (let i = 0; i < votes_b; i++) {
      votes.push({ vote: 'b' });
    }

    // // post votes
    // await Promise.all(votes.map(async (vote) => {
    //   let resp = await voteAPI.post('/vote', vote);
    //   console.log(resp.data);
    // }));

    // // pause a bit to give the worker process time to
    // // process the queue before we run database queries
    // await pause(2 * 1000, 'let the worker service have time to process the queue before querying the reports service');
  });

  after(async () => {
    // // for clean up, drop database created using the test environment
    // let dbConfig = Database.createStdConfig();
    // let db = new Database(dbConfig);
    // await db.connect();
    // await db.instance.dropDatabase();
    // await db.close();
  });

  test('tally votes', async() => {
    let resp = await voteAPI.get('/results');
    assert.ok(resp.data.success);
    let tally = resp.data.result;
    assert.equal(tally.a, votes_a, `'a' => expected: ${votes_a}, actual: ${tally.a}`);
    assert.equal(tally.b, votes_b, `'b' => expected: ${votes_b}, actual: ${tally.b}`);
  });

});

async function pause(ms, reason) {
  return new Promise(resolve => {
    console.warn(`pausing for ${ms} ms...${reason}`);
    setTimeout(resolve, ms);
  });
}