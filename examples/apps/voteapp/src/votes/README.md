## Votes API

Votes service for the Voting App.

### POST /vote

This endpoint is used to cast a vote.

#### Request Body

`application/json`

##### Schema

* `vote` - `string`; currently restricted to either "a" or "b"

##### Example

```
{
  "vote": "a"
}
```

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

