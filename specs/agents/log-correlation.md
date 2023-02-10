## Log correlation

Agents should provide instrumentation/hooks for popular logging libraries in order to decorate structured log records with trace context.
In particular, logging that occurs within the context of a transaction should add the fields `trace.id` and `transaction.id`;
logging that occurs within a span should add the fields `trace.id`, `span.id`, and optionally `transaction.id`.

By adding trace context to log records, users will be able to move between the APM UI and Logs UI.

Logging frameworks and libraries may provide a way to inject key-value pairs in log messages,
this allows to reuse those fields in log message formats (for example in plain text).

Log correlation relies on two sets of fields:
- [metadata fields](#service-correlation-fields)
  - They allow to build the per-service logs view in UI.
  - They are implicitly provided when using log-sending by the agent metadata.
  - When using ECS logging, they might be set by the application.
- [per-log-event fields](#trace-correlation-fields): `trace.id`, `transaction.id` and `error.id`
  - They allow to build the per-trace/transaction/error logs view in UI.
  - They are added to the log event
  - They must be written in each log event document

The values for those fields can be set in two places:
- when using [ecs-logging](https://github.com/elastic/ecs-logging) directly in the application
- when the agent reformats a log event

The values set at the application level have higher priority than the values set by agents.
Agents must provide fallback values if they are not explicitly set by the application.

In case the values set in the application and agent configuration differ, the resulting log
messages won't correlate to the expected service in UI. In order to prevent such inconsistencies
agents may issue a warning when there is a mis-configuration.

### Service correlation fields

They allow to build the per-service logs view in UI.
They are implicitly provided when using log-sending by the agent metadata.
When using ECS logging, they might be set by the application in ECS logging configuration.

- `service.name`:
  - used to filter/link log messages to a given service.
  - must be provided even if there is no active transaction
- `service.version`:
  - only used for service metadata correlation
  - must be provided even if there is no active transaction
- `service.environment`:
  - allows to filter/link log messages to a given service/environment.
  - must be provided even if there is no active transaction

In addition, the `container.id` can be used as a fallback when `service.name` is not avaiable on the log documents.
However, the APM agents are not expected to set it. It is expected to be set by filebeat when ingesting log
documents through auto-discover feature (which captures logs from containers and provides the value).

### Trace correlation fields

They allow to build the per-trace/transaction/error logs view in UI.
They allow to navigate from the log event to the trace/transaction/error in UI.
They should be added to the log event.
They must be written in each log event document they relate to, either reformatted or sent by the agent.

- `trace.id`
- `transaction.id`
- `error.id`
