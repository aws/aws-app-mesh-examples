[![npm (scoped)](https://img.shields.io/npm/v/@subfuzion/database.svg)](@subfuzion/database)
[![node (scoped)](https://img.shields.io/node/v/@subfuzion/database.svg)](@subfuzion/database)
[![Travis](https://img.shields.io/travis/subfuzion/docker-voting-app-nodejs.svg)](https://travis-ci.org/subfuzion/docker-voting-app-nodejs)

# @subfuzion/database

This is a simple database library package that provides the ability to save and tally votes
to a [MongoDB](https://www.mongodb.com/) database. It uses the ES2017 async/await support now available natively in Node.js
and the official MongoDB [Node.js driver](http://mongodb.github.io/node-mongodb-native/2.2).

Votes are stored as documents in the `votes` collection of the `voting` database.

## Testing

The easiest way is to test using Docker Compose.

### Testing with Docker Compose

The following will build an image for running the tests under `test/test.js` and then start
the environment declared in `./docker-compose.test.yml`.

    $ docker-compose -f ./docker-compose.test.yml run sut

If you make changes to any of the Node.js sources, rebuild the test image with the
following command:

    $ docker-compose -f ./docker-compose.test.yml build

To view logs, run:

    $ docker-compose -f ./docker-compose.test.yml logs

When finished with tests, run:

    $ docker-compose -f ./docker-compose.test.yml down

### Testing without Docker Compose

MongoDB needs to be available before running tests. The tests default to
port the standard MongoDB port 27017 on localhost, but host and port can be overridden by setting
HOST and PORT environment variables.

If you have [Docker](https://www.docker.com/) installed, you can easily
start MongoDB with the default values by running the following command:

    $ docker run -d -p 27017:27017 --name mongodb mongodb

This will run a MongoDB container named mongodb in the background with port 27017
on your system mapped to the exposed port 27017 in the container.

To run the tests, enter the following:

    $ npm test

When finished, you can remove the running container from your system with:

    $ docker rm -f mongodb

## Using the @subfuzion/database package with your own Node.js packages

Add the dependency to your package:

npm:

    $ npm install @subfuzion/database

yarn:

    $ yarn add @subfuzion/database

### Create a Database object

Require the package in your module:

    const Database = require('@subfuzion/database').Database;

Create a new instance

    var db = new Database([options])

`options` is an optional object that defaults to the values in `lib/defaults.js` for any missing properties.

```js
const config = {
  host: 'database',
  port: 27017,
  db: 'voting'
};
```

There is a Database helper static method that will create a configuration object that can be
overridden by process environment variables and explicit caller-supplied configuration options:

```js
let config = {
    uri: 'mongodb://database:27017/voting',
};
// or
let config = {
    host: 'database',
    port: '27017',
    db: 'voting'
};

// Any explicit config values will override environment variables, which override internal package defaults
// note: supplied config can be undefined or null or empty
let c = Database.createStdConfig(config);
let db = new Database(c);
await db.connect(options);
```

#### Overriding default connection values with environment variables

If any of the following environment variables are defined in the consumer process creating the connection
using `Database.createStdConfig(options)`, then the values will override the internal package default values.
Any values explicitly supplied in the config object will override environment variables.
If `DATABASE_URI` is specified, it takes precedence over any components specified individually.

    DATABASE_URI - valid mongo connection URI (default: `mongodb://database:27017/voting`)
    If not specified, can override individual URI components:
      DATABASE_HOST - mongo server hostname (default: `database`)
      DATABASE_PORT - mongo connection port (default: `27017`)
      DATABASE_NAME - mongo database name (default: `voting`)

#### Exponential backoff connection strategy

The default connection strategy uses exponential backoff with random jitter. The algorithim is:

    (( 2 ^ count) + jitter) * factor

where
    `count` is the iteration count of the connection attempt (default: 1..(max-1))
    `jitter` is a small random amount (less than 1 second) added to make the timing slightly variable
    `factor` is the number of milliseconds to multiply (default: 1000)

Because of jitter, the following are minimum intervals between each connection attempt
(based on default values):

Attempt 0: immediate
Attempt 1: after 2 second pause
Attempt 2: after 4 second pause
Attempt 3: after 8 second pause
Attempt 4: after 16 second pause
Attempt 5: after 32 second pause

Total attempts: 6  
Total time elapsed until default max retries are exhausted: slightly more than 1 minute

### Storing votes

```js
var db = new Database([options])
let vote = { vote: 'a' } // valid values are 'a' or 'b'
await db.updateVote(vote)
// when finished with the database
await db.close()
```
 
### Tallying votes

```js
var db = new Database([options])
let tally = await db.tallyVotes()
// tally is an object: { a: <number>, b: <number> }
// when finished with the database
await db.close()
```

### Closing Connections

You should close the database connection when finished.

```js
await db.close()
```
