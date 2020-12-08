## HTTP Transactions

Agents should instrument HTTP request routers/handlers, starting a new transaction for each incoming HTTP request. When the request ends, the transaction should be ended, recording its duration.

- The transaction `type` should be `request`.
- The transaction `result` should be `HTTP Nxx`, where N is the first digit of the status code (e.g. `HTTP 4xx` for a 404)
- The transaction `outcome` should be `"success"` for HTTP status codes < 500 and `"failure"` for status codes >= 500. \
  Status codes in the 4xx range (client errors) are not considered a `failure` as the failure has not been caused by the application itself but by the caller.
  As there's no browser API to get the status code of a page load, the RUM agent always reports `"unknown"` for those transactions.
- The transaction `name` should be aggregatable, such as the route or handler name. Examples:
    - `GET /users/{id}`
    - `UsersController#index`

It's up to you to pick a naming scheme that is the most natural for the language or web framework you are instrumenting.

In case a name cannot be automatically determined, and a custom name has not been provided by other means, the transaction should be named `<METHOD> unknown route`, e.g. `POST unknown route`. This would normally also apply to requests to unknown endpoints, e.g. the transaction for the request `GET /this/path/does/not/exist` would be named `GET unknown route`, whereas the transaction for the request `GET /users/123` would still be named `GET /users/{id}` even if the id `123` did not match any known user and the request resulted in a 404.

In addition to the above properties, HTTP-specific properties should be recorded in the transaction `context`, for sampled transactions only. Refer to the [Intake API Transaction](https://www.elastic.co/guide/en/apm/server/current/transaction-api.html) documentation for a description of the various context fields.

By default request bodies are not captured. It should be possible to configure agents to enable their capture using the config variable `ELASTIC_APM_CAPTURE_BODY`. By default agents will capture request headers, but it should be possible to disable their capture using the config variable `ELASTIC_APM_CAPTURE_HEADERS`.

Request and response headers, cookies, and form bodies should be sanitised (i.e. secrets removed). Each agent should define a default list of keys to sanitise, which should include at least the following (using wildcard matching):

  - `password`
  - `passwd`
  - `pwd`
  - `secret`
  - `*key`
  - `*token*`
  - `*session*`
  - `*credit*`
  - `*card*`
  - `authorization`
  - `set-cookie`

Agents may may include additional patterns if there are common conventions specific to language frameworks.

### `transaction_ignore_urls` configuration

Used to restrict requests to certain URLs from being instrumented.

This property should be set to a list containing one or more strings.
When an incoming HTTP request is detected,
its request [`path`](https://tools.ietf.org/html/rfc3986#section-3.3)
will be tested against each element in this list.
For example, adding `/home/index` to this list would match and remove instrumentation from the following URLs:

```
https://www.mycoolsite.com/home/index
http://localhost/home/index
http://whatever.com/home/index?value1=123
```

NOTE: 
All errors that are captured during a request to an ignored URL are still sent to the APM Server regardless of this setting.

|                |   |
|----------------|---|
| Type           | `List<`[`WildcardMatcher`](../../tests/agents/json-specs/wildcard_matcher_tests.json)`>` |
| Default        | agent specific |
| Dynamic        | `true` |
| Central config | `true` |

## HTTP client spans

We capture spans for outbound HTTP requests. These should have a type of `external`, and subtype of `http`. The span name should have the format `<method> <host>`.

For outbound HTTP request spans we capture the following http-specific span context:

- `http.url` (the target URL) \
  The captured URL should have the userinfo (username and password), if any, redacted.
- `http.status_code` (the response status code) \
  The span's `outcome` should be set to `"success"` if the status code is lower than 400 and to `"failure"` otherwise. 
  If the request is aborted the `outcome` should be set to `unknown`.

