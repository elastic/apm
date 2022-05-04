## Span service target

The span service target fields replace the `span.destination.service.*` fields that are deprecated.

However, it does not replace [destination fields](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html)
which are used for APM/SIEM integration and focus on network-level attributes.

- [span.context.destination.address](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#field-destination-address)
- [span.context.destination.port](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#field-destination-port)

APM Agents should now use fields described below in `span.context.service.target`, those are a subset
of [ECS Service fields](https://www.elastic.co/guide/en/ecs/current/ecs-service.html).

- `span.context.service.target.type` : [ECS service.type](https://www.elastic.co/guide/en/ecs/current/ecs-service.html#field-service-type)
  , optional.
- `span.context.service.target.name` : [ECS service name](https://www.elastic.co/guide/en/ecs/current/ecs-service.html#field-service-name)
  , optional, ignored if `span.context.service.target.type` is not provided.

Alignment to ECS provides the following benefits:

- Easier correlation with other data sources like logs and metrics if they also rely on those service fields.
- Posible future extension with other
  ECS [service fields](https://www.elastic.co/guide/en/ecs/current/ecs-service.html) to provide higher-granularity
- Bring APM Agents intake and data stored in ES closer to ECS

On agents side, it splits the values that were previously written into `span.destination.service.resource` in distinct
fields.It provides a generic way to provide higher-granularity for service map and service dependencies.

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

- **Phase 1** : APM server ingest (8.3)
  - Spans intake: `span.context.service.target.*`, store them as-is in ES Span documents
  - Transactions intake: add `service_target_type` and `service_target_name` next to `destination_service_resource` in `transaction.dropped_spans_stats` array, the related metrics documents should include `span.service.target.type` and `span.service.target.name` fields.
  - On the server, service destination metrics and dropped spans metrics should be updated to include new dimensions: `span.service.target.type` and `span.service.target.name` next to the existing
   `span.destination.service.resource`, `span.destination.service.response_time.*` fields and their aggregation remain untouched for now.
- **Phase 2** : modify one or more agents to:
  - Add and capture values for `span.context.service.target.type` and `span.context.service.target.name` for exit spans.
  - Infer from those new fields the value of `span.destination.service.resource` and keep sending it.
  - Add `service_target_*` fields to dropped spans metrics (as described in Phase 1)
  - Handle span compression with new fields (stop relying on `resource` internally)
- **Phase 3** : infer on APM Server for agents that DO NOT provide the new fields (unknown APM Server version yet)
  - `span.destination.service.resource` inferred from `span.context.service.target.*`
  - dropped spans metrics
- **Phase 4** : modify the agents not covered in Phase 2
  - Add `span.context.service.target.type` and `span.context.service.target.name`
  - Handle dropped spans metrics with only the new fields
  - Handle span compression with new fields
- **Phase 5** : cleanup of agents modified in Phase 2
  - When sending to APM Server with **Phase3** implemented
    - stop inferring & sending `span.destination.service.resource` on the agent
    - stop inferring & sending `destination_service_resource` in dropped spans stats
  - Keep sending and inferring for previous APM server versions

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

(2) Value is inferred and sent by APM agents in Phase 2, inferred on APM Server once Phase 3 is complete

(3) We have to omit the `_.type` field in the inferred destination resource for compatibility.

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
  
  if (!service_target.type) { // infer type from span type & subtype
      
    // use sub-type if provided, fallback on type othewise
    service_target.type = span.subtype || span.type;
  }
  
  if (!service_target.name) { // infer name from span attributes
      
    if (span.context.db.instance) {  // database spans
      service_target.name = span.context.db.instance;

    } else if (span.context.message) { // messaging spans
      service_target.name = span.context.message.queue.name

    } else if (context.http.url) { // http spans
      service_target.name = context.http.host;
      if (context.http.url.port > 0) {
        service_target.name += ":" + context.http.port;
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

### Phase 3

In Phase 3 the `span.destination.service.resource` field value is inferred on APM Server with the following algorithm:

```javascript

// span from agent intake
span = {};

// inferred destination resource (if any)
destination_resource = undefined;

if (span.service.target.type) {
  // new fields, store them as-provided
  // infer resource destination from new fields
  destination_resource = span.service.target.type;
  if (span.service.target.name) {
    destination_resource += "/";
    destination_resource += span.service.target.name;
  }

} else if (['db', 'messaging', 'external'].indexOf(span.type) >= 0) {
  // agent intake without new fields
  // only a subset of span types should be included
  span.service.target = {};

  // inferred service target type & name
  target_type = undefined;
  target_name = undefined;

  if (span.destination.service.resource) {
    // infer new fields values from destination resource if provided
    r = span.destination.service.resource;
    separatorIndex = r.indexOf('/');
    if (separatorIndex <= 0) {
      target_type = r;
    } else {
      target_type = r.substr(0, separatorIndex);
      target_name = r.substr(separatorIndex + 1);
    }
  } else {
    // no destination resource, fallback from span type & subtype
    target_type = span.type;
    if (span.subtype) {
      target_name = span.subtype;
    }
  }

  if (target_name.length == 0) {
    // normalization: do not store empty name
    target_name = undefined;
  }

  span.service.target.type = target_type;
  span.service.target.name = target_name;

}

if (destination_resource) {
  span.destination.service.resource = destination_resource;
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
