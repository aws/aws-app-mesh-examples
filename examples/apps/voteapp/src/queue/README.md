[![npm (scoped)](https://img.shields.io/npm/v/@subfuzion/database.svg)](@subfuzion/database)
[![node (scoped)](https://img.shields.io/node/v/@subfuzion/queue.svg)](@subfuzion/queue)
[![Travis](https://img.shields.io/travis/subfuzion/docker-voting-app-nodejs.svg)](https://travis-ci.org/subfuzion/docker-voting-app-nodejs)

# @subfuzion/queue

This is a simple Node.js **queue** library package that provides a **Producer** class
for enqueueing messages and a **Consumer** class for dequeueing them. The queue
is backed by [Redis](https://redis.io/) and this package provides a trivial
wrapper over the [ioredis](https://github.com/luin/ioredis) client for Node.js.
This package uses ES2017 async/await support now available natively
in Node.js.

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

Redis needs to be available before running tests. The tests default to
port 6379 on localhost, but host and port can be overridden by setting
HOST and PORT environment variables.

If you have [Docker](https://www.docker.com/) installed, you can easily
start Redis with the default values by running the following command:

    $ docker run -d -p 6379:6379 --name queue redis

This will run a redis container named queue in the background with port 6379
on your system mapped to the exposed port 6379 in the container.

To run the tests, enter the following:

    $ npm test

When finished, you can remove the running container from your system with:

    $ docker rm -f queue

## Using the @subfuzion/queue package with your own Node.js packages

Add the dependency to your package:

npm:

    $ npm install @subfuzion/queue

yarn:

    $ yarn add @subfuzion/queue

### Create a Producer or Consumer object

Require the package in your module:

    const Producer = require('@subfuzion/queue').Producer;
    const Consumer = require('@subfuzion/queue').Consumer;

Create a new instance

    var producer = new Queue([options])
    var consumer = new Queue([options])

`options` is an optional object that defaults to the values in `lib/defaults.js` for any missing properties.

```js
const config = {
  host: 'queue',
  port: 6379
};
```

There is a Queue helper static method that will create the configuration that can be overridden by
environment variables:

```js
let defaults = {};
// explicit defaults will override environment variables, environment overrides internal defaults
let config = Queue.createStdConfig(defaults);
let p = new Producer(topic, config);
let c = new Consumer(topic, config);
```

If any of the following environment variables are defined, then the values will override
the default values. Any values explicitly supplied in the config object will override the
environment.

    QUEUE_URI - valid redis connection URI
    otherwise:
      QUEUE_HOST - hostname for the redis server
      QUEUE_PORT - port that redis is listening on


### Enqueueing Messages

    var p = new Producer(topic [, config])
    await p.send(message)
    // when finished with the producer:
    await p.quit()
 
where `topic` should be the queue topic and `config` is an optional
object that can have `host` and `port` values.
 
### Dequeueing Messages

    var c = new Consumer(topic [, config])
    let message = await c.receive(topic)
    // when finished with the consumer: 
    await c.quit()

where `topic` and `config` are the same as described previously.

Note that the receive method blocks until there is a message ready to
be retrieved from the queue. The method will return null if the connection
is closed (by calling quit) while it is waiting.

### Closing Connections

You should always call quit on producers and consumers to ensure
connections are gracefully closed on both the client and server sides.

