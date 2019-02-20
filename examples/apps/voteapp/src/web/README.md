## Voting App web service

This service is a gateway to the votes and reports services.

The service can be started with the following environment variable overrides:

`PORT`: the vote service listening port (defaults to port `3000`)
`VOTES_URI`: the **votes** API backend microservice (defaults to: http://votes:3000/)
`REPORTS_URI`: the **reports** API backend microservice (defaults to: http://reports:3000/)

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

This endpoint is used to query the voting results.

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
