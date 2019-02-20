[![Travis](https://img.shields.io/travis/subfuzion/vote-worker.svg)](https://travis-ci.org/subfuzion/vote-worker)

# worker service

This is a simple worker service that reads votes that have been
pushed to a queue and stores them to the database.

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
 
 ## Stopping a worker
 
 The worker process handles the SIGTERM (and SIGINT) signal to
 gracefully write votes pulled from the queue to the database
 before closing connections.
 
