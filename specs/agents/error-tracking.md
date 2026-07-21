## Error/exception tracking

The agent support reporting exceptions/errors. Errors may come in one of two forms:

 - unhandled (or handled and explicitly reported) exceptions/errors
 - log records

Agents should include exception handling in the instrumentation they provide, such that exceptions are reported to the APM Server automatically, without intervention. In addition, hooks into logging libraries may be provided such that logged errors are also sent to the APM Server.

Error properties
* `id` (which in the case of errors is 128 bits, encoded as 32 hexadecimal digits)

Additional properties that agents SHOULD collect when the error happens within the context of a transaction
* `trace_id`
* `transaction_id`
* `parent_id` (which is the `id` of the transaction or span that caused the error).
* `transaction.sampled`
* `transaction.name`†
* `transaction.type`†

† These properties may change during the lifetime of a transaction, for example if a user explicitly sets the transaction name after an error has been captured.
It is a known and accepted limitation that these properties are not always consistent with the transaction.
Agents MUST NOT buffer errors to ensure consistency as this comes at the expense of increased memory overhead.

### Breadcrumbs

Status: Experimental

Breadcrumbs are a bounded, chronological list of events that occurred before an
error. They provide debugging context such as navigation, user interaction, log,
HTTP, and application events without requiring each event to be independently
reported to APM Server.

Agents MAY collect breadcrumbs and attach them to an error as
`error.context.breadcrumbs`. Breadcrumbs MUST be embedded in the error event;
they MUST NOT be sent as independent events or rely on a session or trace being
available. This ensures that the context remains available for errors outside a
transaction and that the list represents the agent's view at capture time.

RUM and mobile agents SHOULD support automatic breadcrumb collection. Other
agents MAY support automatic collection when it can be implemented with bounded
overhead. Agents that support breadcrumbs SHOULD provide a public API for adding
a breadcrumb manually.

Each breadcrumb has the following fields:

| Intake API field | Type | Required | Description |
| ---------------- | ---- | -------- | ----------- |
| `context.breadcrumbs[].timestamp` | integer | yes | Microseconds since the Unix epoch. |
| `context.breadcrumbs[].category` | string | yes | A low-cardinality source, such as `navigation`, `ui`, `http`, `log`, or `custom`. |
| `context.breadcrumbs[].type` | string | no | A more specific event type within the category. |
| `context.breadcrumbs[].message` | string | no | A human-readable description of the event. |
| `context.breadcrumbs[].level` | string | no | Severity when applicable, using the agent's canonical log levels. |
| `context.breadcrumbs[].data` | object | no | Additional, non-indexed key-value context. |

The corresponding Elasticsearch field is `error.breadcrumbs`. The field and
all of its children MUST NOT be indexed. Kibana SHOULD display the entries in
timestamp order as a timeline on the error occurrence and error group detail
pages. Unknown categories and types MUST still be displayed.

The proposed Intake API JSON Schema is:

```json
{
  "breadcrumbs": {
    "type": ["null", "array"],
    "maxItems": 100,
    "items": {
      "type": "object",
      "required": ["timestamp", "category"],
      "properties": {
        "timestamp": { "type": "integer" },
        "category": { "type": "string", "maxLength": 1024 },
        "type": { "type": ["null", "string"], "maxLength": 1024 },
        "message": { "type": ["null", "string"], "maxLength": 1024 },
        "level": { "type": ["null", "string"], "maxLength": 1024 },
        "data": { "type": ["null", "object"] }
      }
    }
  }
}
```

#### Limits and ordering

Agents MUST retain at most 100 breadcrumbs and MUST use a bounded in-memory
buffer. When the buffer is full, adding a breadcrumb MUST discard the oldest
entry. Breadcrumbs MUST be attached oldest first. Agents MAY use a lower default
limit to satisfy platform constraints, and MAY provide a configuration option
with an upper bound of 100.

String fields, including string values in `data`, MUST follow the standard
[field limit and truncation rules](field-limits.md). Agents MUST limit the
serialized `data` object of each breadcrumb to 4 KiB and the serialized
breadcrumb list to 64 KiB. When a size limit is reached, agents MUST first drop
`data`, then drop the oldest breadcrumbs until the list fits. Agents MUST NOT
drop or delay the error event because its breadcrumb context exceeds a limit.

#### Sanitization and privacy

Breadcrumb collection MAY capture secrets or personally identifiable
information. Automatic collection MUST NOT capture request or response bodies,
cookies, HTTP headers, form fields, DOM text, input values, or URL user-info.
URLs MUST have their fragments removed. Query strings SHOULD be omitted by
default; an agent MAY retain them only when its existing URL-capture behavior
and documentation already permit this.

For `data`, keys matching [`sanitize_field_names`](sanitization.md) MUST have
their values replaced with the agent's standard redaction value. This applies
recursively to nested objects. Manually added breadcrumbs MUST be sanitized in
the same way as automatically collected breadcrumbs. Agents MUST document the
automatic breadcrumb sources they enable and provide a way to disable automatic
collection.

### Impact on the `outcome`

Tracking an error that's related to a transaction does not impact its `outcome`.
A transaction might have multiple errors associated to it but still return with a 2xx status code.
Hence, the status code is a more reliable signal for the outcome of the transaction.
This, in turn, means that the `outcome` is always specific to the protocol.
