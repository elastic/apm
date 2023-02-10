## Log correlation

Agents should provide instrumentation/hooks for popular logging libraries in order to decorate structured log records with trace context.
In particular, logging that occurs within the context of a transaction should add the fields `trace.id` and `transaction.id`;
logging that occurs within a span should add the fields `trace.id`, `span.id`, and optionally `transaction.id`.

By adding trace context to log records, users will be able to move between the APM UI and Logs UI.

Logging frameworks and libraries may provide an MDC (Message Diagnostic Context) that allow to also
reuse those fields in log message formats (for example in plain text).

Log correlation is implemented by adding the following fields to a log document:
- `service.name`:
  - used to filter/link log messages to a given service.
  - must be provided even if there is no active transaction
- `service.version`:
  - only used for service metadata correlation
  - must be provided even if there is no active transaction
- `service.environment`:
  - allows to filter/link log messages to a given service/environment.
  - must be provided even if there is no active transaction
- `trace.id` and `transaction.id`
  - allows to correlate with the APM trace/transaction.
  - should be added to the MDC
- `error.id`:
  - allows to correlate with an Error.
  - should be added to the MDC

The values for those fields can be set in two places:
- when using [ecs-logging](https://github.com/elastic/ecs-logging) directly in the application
- when the agent reformats a log event

The values set at the application level have higher priority than the values set by agents.
Agents must provide fallback values if they are not explicitly set by the application.

In case the values set in the application and agent configuration differ, the resulting log
messages won't correlate to the expected service in UI. In order to prevent such inconsistencies
agents may issue a warning when there is a mis-configuration.

See also the [log-reformatting](log-reformatting.md) spec.

