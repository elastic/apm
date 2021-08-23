## Field limits

The maximum length of metadata, transaction, span, et al fields are determined
by the [APM Server Events Intake API schema](https://www.elastic.co/guide/en/apm/server/current/events-api.html).
Fields that are names or identifiers of some resource of typically limited to
1024 unicode characters.

### `long_field_max_length` configuration

Some APM event fields are not limited in the APM server intake API schema.
Agents SHOULD limit the maximum length of the following fields by truncating.

- `{transaction,error}.context.request.body`
- `{transaction,span,error}.context.message.body`
- `span.context.db.statement`
- `error.exception.message`
- `error.log.message`

Agents MAY support the `long_field_max_length` configuration option to allow
the user to configure this maximum length.

|                |   |
|----------------|---|
| Type           | [`Size`](./configuration.md#configuration-value-types) |
| Default        | `"10000b"` |
| Dynamic        | `true` |
| Central config | `true` |

Ultimately the maximum length of any field is limited by the [`max_event_size`](https://www.elastic.co/guide/en/apm/server/current/configuration-process.html#max_event_size)
configured for the receiving APM server.
