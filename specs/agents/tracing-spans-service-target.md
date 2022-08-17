## Span service target

The span service target fields replace the `span.destination.service.*` fields that are deprecated.

However, it does not replace [destination fields](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html)
which are used for APM/SIEM integration and focus on network-level attributes.

- [span.context.destination.address](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#field-destination-address)
- [span.context.destination.port](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#field-destination-port)

APM Agents should now use fields described below in `span.context.service.target` for exit spans, those are a subset
of [ECS Service fields](https://www.elastic.co/guide/en/ecs/current/ecs-service.html).

- `span.context.service.target.type` : [ECS service.type](https://www.elastic.co/guide/en/ecs/current/ecs-service.html#field-service-type)
  , optional, might be empty.
- `span.context.service.target.name` : [ECS service name](https://www.elastic.co/guide/en/ecs/current/ecs-service.html#field-service-name)
  , optional.
- at least one of those two fields is required to be provided and not empty

Alignment to ECS provides the following benefits:

- Easier correlation with other data sources like logs and metrics if they also rely on those service fields.
- Posible future extension with other
  ECS [service fields](https://www.elastic.co/guide/en/ecs/current/ecs-service.html) to provide higher-granularity
- Bring APM Agents intake and data stored in ES closer to ECS

On agents side, it splits the values that were previously written into `span.destination.service.resource` in distinct
fields. It provides a generic way to provide higher-granularity for service map and service dependencies.

#### APM Agents

There are a few features in APM Agents relying on `span.destination.service.resource`:

- Dropped spans metrics
- Compressed spans
- Agent API might provide a way to manually set the `span.destination.service.resource`, if such API exists we should provide an equivalent to enable setting `span.service.target.type` and `span.service.target.name`.

#### APM Server

The following features rely on `span.destination.service.resource` field:

- APM Map
- APM Services Dependencies
- Dropped spans metrics (indirect dependency)

As a result, we need to make APM server handle the compatibility with those for both existing and new agents.

### Implementation phases

Because there are a lots of moving pieces, implementation will be split into multiple phases:

- **Phase 1** : APM server ingest + compatibility for older agents
  - Spans intake: `span.context.service.target.*`, store them as-is in ES Span documents
  - Transactions intake: add `service_target_type` and `service_target_name` next to `destination_service_resource` in `transaction.dropped_spans_stats` array, the related metrics documents should include `span.service.target.type` and `span.service.target.name` fields.
  - On the server, service destination metrics and dropped spans metrics should be updated to include new dimensions: `span.service.target.type` and `span.service.target.name` next to the existing
   `span.destination.service.resource`, `span.destination.service.response_time.*` fields and their aggregation remain untouched for now.
  - compatibility: fields `span.context.service.target.*` are inferred from `span.destination.service.resource`
  - compatibility: dropped spans and destination metrics still able to use provided `span.destination.service.resource`.
- **Phase 2** : modify one or more agents to:
  - Add and capture values for `span.context.service.target.type` and `span.context.service.target.name` for exit spans.
  - Infer from those new fields the value of `span.destination.service.resource` and keep sending it.
  - Add `service_target_*` fields to dropped spans metrics (as described in Phase 1)
  - Handle span compression with new fields (stop relying on `resource` internally)
- **Phase 3** : modify the agents not covered in Phase 2
  - Add `span.context.service.target.type` and `span.context.service.target.name`
  - Handle dropped spans metrics with only the new fields
  - Handle span compression with new fields
- **Phase 4** : modify the UI to display and query new fields (to be further clarified)
  - service dependencies
  - service maps
  - display fallback on `resource` field when `span.context.service.target.type` is empty

### Examples

1. Database call to a `mysql` server without database instance name
2. Database call to a `mysql` server on the `my-db` database
3. Send message on `rabbitmq` server without queue
4. Send message on `rabbitmq` server on the `my-queue` queue
5. HTTP request to `host:80` server

| Span field                                      | #1      | #2            | #3          | #4                  | #5            |
|-------------------------------------------------|---------|---------------|-------------|---------------------|---------------|
| `span.type`                                     | `db`    | `db`          | `messaging` | `messaging`         | `external`    |
| `span.subtype`                                  | `mysql` | `mysql`       | `rabbitmq`  | `rabbitmq`          | `http`        |
| `span.context.service.target.type`              | `mysql` | `mysql`       | `rabbitmq`  | `rabbitmq`          | `http`        |
| `span.context.service.target.name` (1)          |         | `my-db`       |             | `my-queue`          | `host:80`     |
| `span.context.destination.service.resource` (2) | `mysql` | `mysql/my-db` | `rabbitmq`  | `rabbitmq/my-queue` | `host:80` (3) |

(1) Value depends on the instrumented backend, see [below](#field-values) for details.

(2) Value is always sent by APM agents for compatibility, but they SHOULD NOT rely on it internally.

(3) HTTP spans (and a few other spans) can't have their `resource` value inferred on APM server without relying on a
brittle mapping on span `type` and `subtype` and breaking the breakdown metrics where `type` and `subtype` are not available.

## Implementation details

This specification assumes that values for `span.type` and `span.subtype` fit the [span_types.json](../../tests/agents/json-specs/span_types.json) specification.

### Field values

- `span.context.service.target.*` fields should be omitted for non-exit spans.
- Values set by user through the agent API should have priority over inferred values.
- `span.context.service.target.type` should have the same value as `span.subtype` and fallback to `span.type`.
- `span.context.service.target.name` depends on the span context attributes

On agents, the following algorithm should be used to infer the values for `span.context.service.target.*` fields.

```javascript
// span created on agent
span = {};

if (span.isExit) {
  service_target = span.context.service.target;

  if ('type' in service_target) { // if not manually specified, infer type from span type & subtype

    // use sub-type if provided, fallback on type othewise
    service_target.type = span.subtype || span.type;
  }

  if (!service_target.name) { // infer name from span attributes

    if (span.context.db) {  // database spans
      service_target.name = span.context.db.instance;

    } else if (span.context.message) { // messaging spans
      service_target.name = span.context.message.queue?.name

    } else if (context.http?.url) { // http spans
      service_target.name = getHostFromUrl(context.http.url);
      port = getPortFromUrl(context.http.url);
      if (port > 0) {
        service_target.name += ":" + port;
      }
    }

  }
} else {
    // non-exit spans should not have service.target.* fields
    span.context.service.target = undefined;
}
```

The values for `span.context.db.instance` are described in [SQL Databases](./tracing-instrumentation-db.md#sql-databases).

The values for `span.context.message.queue.name` are described in [Messaging context fields](./tracing-instrumentation-messaging.md#context-fields)

### User API

Agents SHOULD provide an API entrypoint to set the value of `span.context.destination.service.resource`,
setting an empty or `null` value allows the user to discard the inferred value.
This API entrypoint should be marked as deprecated and replaced by the following:

Agents SHOULD provide an API entrypoint to set the value of `span.context.service.target.type` and `span.context.service.target.name`,
setting an empty or `null` value on both of those fields allows the user to discard the inferred values.

When a user-provided value is set, it should take precedence over inferred values from the span `_.type` `_.subtype` or any `_.context` attribute.

In order to provide compatibility with existing agent API usage, when user calls the deprecated method to set `_.resource` = `"<some-value>"`,
agents MAY set `_.type` = `""` (empty string) and `_.name` = `"<some-value>"`, which replicates the behavior on APM server described below.

### Phase 1 - server-side compatibility

In Phase 1 the `span.service.target.{type,name}` fields are inferred on APM Server with the following algorithm and internal
usage of `resource` field in apm-server can be replaced with `span.service.target.{type,name}` fields.

When this phase is implemented, the stored spans can be summarized as follows:

| `span.context._`                                           | `_.destination.service.resource`                | `_.service.target.type`                           | `_.service.target.name`                  |
|------------------------------------------------------------|-------------------------------------------------|---------------------------------------------------|------------------------------------------|
| Non-exit span                                              | -                                               | -                                                 | -                                        |
| Exit span captured before server 8.3                       | `mysql`, `mysql/myDb`                           | -                                                 | -                                        |
| Exit span captured with server 8.3 or later + legacy agent | `mysql`<br/> `mysql/myDb`<br/> `localhost:8080` | `mysql`<br/> `mysql`<br/> `""` (empty string) (1) | -<br/> `myDb`<br/> `localhost:8080`      |
| Exit span captured with server 8.3 + latest agent          | `mysql`<br/> `mysql/myDb`<br/> `localhost:8080` | `mysql`<br/> `mysql`<br/> `http` or `grpc`    (2) | -<br/> `myDB`<br/> `localhost:8080` (2) |

(1) : APM Server can't infer the value of the equivalent `service.target.type`, so we use the empty string `""` to allow UI to fallback on using the `_.resource` or `_.service.target.name` for display and compatibility.

(2) : in this case the values are provided by the agent and not inferred by APM server.

```javascript

// Infer new fields values from an existing 'resource' value
// Empty type value (but not null) that can be used on UI to use the existing resource for display.
// For internal aggregation on (type,name) and usage this will be equivalent to relying on 'resource' value.
inferFromResource = function (r) {

    singleSlashRegex = new RegExp('^([a-z0-9]+)/(\w+)$').exec(r);
    typeOnlyRegex = new RegExp(('^[a-z0-9]+$')).exec(r);

    if (singleSlashRegex != null) {
        // Type + breakdown
        // e.g. 'mysql/mydatabase', 'rabbitmq/myQueue'
        return {
            type: singleSlashRegex[1],
            name: singleSlashRegex[2]
        }

    } else if (typeOnlyRegex != null) {
        // Type only
        // e.g. 'mysql'
        return {
            type: r,
        };

    } else {
        // Other cases, should rely on default, UI will have to display resource as fallback
        // e.g. 'localhost:8080'

        return {
            type: '',
            name: r
        }
    }
}

// usage with span from agent intake
span = {};

if (!span.service.target.type && span.destination.service.resource) {
    // try to infer new fields from provided resource

    inferred = inferFromResource(span.destination.service.resource);
    span.service.target.type = inferred.type;
    span.service.target.name = inferred.name;
}

```

#### OTel and bridge compatibility

APM server already infers the `span.destination.service.resource` value from OTel span attributes, this algorithm needs
to be updated in order to also infer the values of `span.context.service.target.*` fields.
- `span.context.service.target.type` should be set from the inferred value of `span.subtype` with fallback to `span.type`
  - For database spans: use value of `db.system` attribute
  - For HTTP client spans: use `http`
  - For messaging spans: use value of `messaging.system` attribute
  - For RPC spans: use value of `rpc.system` attribute
- `span.context.service.target.name` should be set from OTel attributes if they are present
  - For database spans: use value of `db.name` attribute
  - For HTTP client spans: create `<host>:<port>` string from `http.host`, `net.peer.port` attributes or equivalent
  - For messaging spans: use value of `messaging.destination` attribute if `messaging.temp_destination` is `false` or absent to limit cardinality
  - For RPC spans: use value of `rpc.service`

When OTel bridge data is sent in `_.otel.attributes` for spans and transactions captured through agent OTel bridges,
the inferred values on OTel attributes should take precedence over the equivalent attributes in regular agent protocol.
