## Field limits

The maximum length of metadata, transaction, span, et al fields are determined
by the [APM Server Events Intake API schema](https://www.elastic.co/guide/en/apm/server/current/events-api.html).
Except for special cases, fields are typically limited to 1024 unicode characters. 
Unless listed below as knowm "long fields", agents SHOULD truncate filed values to 1024 characters, as specified [below](#truncating-field-values).

### Long fields

Some APM event fields are not limited in the APM server intake API schema. 
Such fields are considered "long fields".

Agents SHOULD treat the following fields as long fields:

- `transaction.context.request.body`, `error.context.request.body`
- `transaction.context.message.body`, `error.context.message.body`
- `span.context.db.statement`

In addition, agents MAY treat the following fields as long fields:

- `error.exception.message`
- `error.log.message`

Agents SHOULD limit the maximum length of long fields by [truncating](#truncating-field-values) them to 10,000 unicode characters, 
or based on user configuration for long field length, as specified [below](#long_field_max_length-configuration).

### `long_field_max_length` configuration

Agents MAY support the `long_field_max_length` configuration option to allow
the user to configure this maximum length. This option defines a maximum number
of unicode characters for each field.

|                |           |
|----------------|-----------|
| Type           | `Integer` |
| Default        | `10000` |
| Dynamic        | `false` |
| Central config | `false` |

Ultimately the maximum length of any field is limited by the [`max_event_size`](https://www.elastic.co/guide/en/apm/server/current/configuration-process.html#max_event_size)
configured for the receiving APM server.

### Truncating field values

When field values exceed the maximum allowed number of unicode characters, agents SHOULD truncate the valiues to fit the maximum allowed length, 
replacing the last character of the eventual value with the ellipsis chracter (unicode character `U+2026`: "&#x2026;").
