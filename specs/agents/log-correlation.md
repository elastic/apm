## Logging Correlation

Agents should provide instrumentation/hooks for popular logging libraries in order to decorate structured log records with trace context. In particular, logging that occurs within the context of a transaction should add the fields `trace.id` and `transaction.id`; logging that occurs within a span should add the fields `trace.id`, `span.id`, and optionally `transaction.id`.

By adding trace context to log records, users will be able to move between the APM UI and Logs UI.

See also the [logging](logging.md) spec.
