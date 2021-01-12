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

### `omit_captured_fields`

A list of captured field names to omit. This list is applied to all fields that the agent captures and if a field name is matching then the field will be omitted.

Every matching field will be omitted except required fields. In case of required field, this config is ignored.

#### Omitting Values

If a field's name matches a configured
wildcard, that field's _value_ MUST be omitted and the key itself
MAY still be reported in the agent payload.

#### Example: 

`omit_captured_fields=user.*` omits all `transaction.context.user` fields and `omit_captured_fields=user.ema*l` only omits `transaction.context.user.email`.

|                |   |
|----------------|---|
| Type           | `List<`[`WildcardMatcher`](../../tests/agents/json-specs/wildcard_matcher_tests.json)`>` |
| Default        | empty list |
| Dynamic        | `true` |
| Central config | `true` |
