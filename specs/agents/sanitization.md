## Data sanitization

### `sanitize_field_names` configuration

Sometimes it is necessary to sanitize, i.e., remove,
sensitive data sent to Elastic APM.
This config accepts a list of wildcard patterns of field names which should be sanitized.
These apply to HTTP headers (including cookies) and `application/x-www-form-urlencoded` data (POST form fields).
The query string and the captured request body (such as `application/json` data) will not get sanitized.

|                |   |
|----------------|---|
| Type           | `List<`[`WildcardMatcher`](../../tests/agents/json-specs/wildcard_matcher_tests.json)`>` |
| Default        | `password, passwd, pwd, secret, *key, *token*, *session*, *credit*, *card*, authorization, set-cookie` |
| Dynamic        | `true` |
| Central config | `true` |
