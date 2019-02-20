const assert = require('assert');
const axios = require('axios');
const Database = require('@subfuzion/database').Database;

suite('vote tests', () => {
  let ax = axios.create({
    baseURL: 'http://database-proxy:3000/'
  });

  let votes_a = 3;
  let votes_b = 2;

  let db;

  after(async () => {
    // for clean up, drop database created using the test environment
    let dbConfig = Database.createStdConfig();
    let db = new Database(dbConfig);
    await db.connect();
    await db.instance.dropDatabase();
    await db.close();
  });

  test('post votes', async () => {
    // test the /vote route
    // initialize test data
    let votes = [];
    for (let i = 0; i < votes_a; i++) {
      votes.push({ vote: 'a' });
    }
    for (let i = 0; i < votes_b; i++) {
      votes.push({ vote: 'b' });
    }

    // post votes
    await Promise.all(votes.map(vote => ax.post('/vote', vote)));
  });

  test('tally votes', async () => {
    // test the /results route
    let resp = await ax.get('/results');
    assert.ok(resp.data.success);
    let tally = resp.data.result;
    assert.equal(tally.a, votes_a, `'a' => expected: ${votes_a}, actual: ${tally.a}`);
    assert.equal(tally.b, votes_b, `'b' => expected: ${votes_b}, actual: ${tally.b}`);
  });

});
