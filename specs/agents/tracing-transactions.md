### Transactions

Transactions are a special kind of span.
They represent the entry into a service.
They are sometimes also referred to as local roots or entry spans.

Transactions are created either by the built-in auto-instrumentation or an agent or the [tracer API](tracing-api.md).

#### Transaction outcome

The `outcome` property denotes whether the transaction represents a success or a failure from the perspective of the entity that produced the event.
The APM Server converts this to the [`event.outcome`](https://www.elastic.co/guide/en/ecs/current/ecs-allowed-values-event-outcome.html) field.
This property is optional to preserve backwards compatibility.
If an agent doesn't report the `outcome` (or reports `null`), the APM Server sets the outcome to `"unknown"`.

- `"failure"`: Indicates that this transaction describes a failed result. \
  Note that client errors (such as HTTP 4xx) don't fall into this category as they are not an error from the perspective of the server.
- `"success"`: Indicates that this transaction describes a successful result.
- `"unknown"`: Indicates that there's no information about the outcome.
  This is the default value that applies when an outcome has not been set explicitly.
  This may be the case when a user tracks a custom transaction without explicitly setting an outcome.
  For existing auto-instrumentations, agents should set the outcome either to `"failure"` or `"success"`.

What counts as a failed or successful request depends on the protocol and does not depend on whether there are error documents associated with a transaction.

Agents should expose an API to manually override the outcome.
This value must always take precedence over the automatically determined value.
