## database http proxy

This is an HTTP proxy for the database service, which otherwise expects
a connection using the Mongo protocol (`mongodb://`) usually over port
`27017`.

## Connecting to the database backend

If any of the following environment variables are defined, then the values will override
default connection values for connecting to the database backend (mongo server):

    DATABASE_URI - valid mongo connection URI (default: `mongodb://database:27017/voting`)
    If not specified, can override individual URI components:
      DATABASE_HOST - mongo server hostname (default: `database`)
      DATABASE_PORT - mongo connection port (default: `27017`)
      DATABASE_NAME - mongo database name (default: `voting`)

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

### GET /results

This endpoint is used to query vote results.

#### Response

`application/json`

* `success` - `boolean`

* `result` - `object`; present only if success. The object has a property named for each vote ("a", "b"); the value of the property is a `number` corresponding to the number of votes cast.

* `reason` - `string`; present only if success is false.

#### Example:

```
{
  "success": true,
  "result": {
    "a": 5,
    "b": 3
  }
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
