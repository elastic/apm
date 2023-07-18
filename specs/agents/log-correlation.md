## Log correlation

Agents should provide instrumentation/hooks for popular logging libraries in order to decorate structured log records with trace context.
In particular, logging that occurs within the context of a transaction should add the fields `trace.id` and `transaction.id`;
logging that occurs within a span should add the fields `trace.id` and optionally `transaction.id`.

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
  - Configuration source (in order of precedence):
    - Configured value
    - `ELASTIC_APM_SERVICE_NAME`
    - `OTEL_SERVICE_NAME`
    - `OTEL_RESOURCE_ATTRIBUTES` value for `service.name`
    - Default from Elastic Agent (if available)
- `service.version`:
  - only used for service metadata correlation
  - must be provided even if there is no active transaction
  - Configuration source (in order of precedence):
    - Configured value
    - `ELASTIC_APM_SERVICE_VERSION`
    - `OTEL_RESOURCE_ATTRIBUTES` value for `service.version`
    - Default from Elastic Agent (if available)
- `service.environment`:
  - allows to filter/link log messages to a given service/environment.
  - must be provided even if there is no active transaction
  - Configuration source (in order of precedence):
    - Configured value
    - `ELASTIC_APM_ENVIRONMENT`
    - `OTEL_RESOURCE_ATTRIBUTES` value for `deployment.environment`
    - Default from Elastic Agent (if available)
- `service.node.name`:
  - must be provided even if there is no active transaction
  - Configuration source (in order of precedence):
    - Configured value
    - `ELASTIC_APM_SERVICE_NODE_NAME`
    - `OTEL_RESOURCE_ATTRIBUTES` value for `service.instance.id`
    - Default from Elastic Agent (if available)


The `container.id` field can also be used as a fallback to provide service-level correlation in UI, however agents ARE NOT expected to set it:

- log collector (filebeat) is expected to do that when ingesting logs.
- all data sent through agent intake implicitly provides `container.id` through metadata, which also includes the log events that may be sent to apm-server.

### Trace correlation fields

They allow to build the per-trace/transaction/error logs view in UI.
They allow to navigate from the log event to the trace/transaction/error in UI.
They should be added to the log event.
They must be written in each log event document they relate to, either reformatted or sent by the agent.

- `trace.id`
- `transaction.id`
- `error.id`
