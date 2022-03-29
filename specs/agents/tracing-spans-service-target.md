## Span service target

The span service target fields replace the `span.destination.service.*` fields that are deprecated.

However, it does not replace [destination fields](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html)
which are used for APM/SIEM integration and focus on network-level attributes.

- [span.context.destination.address](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#field-destination-address)
- [span.context.destination.port](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#field-destination-port)

TODO : link to other spec + mark the other one as deprecated, should be removed at a later stage.

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

### Implementation phases

Because there are a lots of moving pieces, implementation will be split into multiple phases:

- **Phase 1** : add `span.context.service.target.*` to APM Server intake, store them as-is in ES (8.3)
  - TODO : is there anything required to ingest metrics with extra dimensions ?
- **Phase 2** : modify one or more agents to:
  - Add and capture values for `span.context.service.target.type` and `span.context.service.target.name` for exit spans.
  - Infer from those new fields the value of `span.destination.service.resource` and keep sending it
  - Handle dropped spans metrics with new fields (extra dimensions to the metrics)
  - Handle span compression with new fields (stop relying on `resource` internally)
- **Phase 3** : infer `span.destination.service.resource` on APM Server from `span.context.service.target.*` (8.3 or later)
- **Phase 4** : modify the agents not covered in Phase 2
  - Add `span.context.service.target.type` and `span.context.service.target.name`
  - Handle dropped spans metrics with new fields
  - Handle span compression with new fields
- **Phase 5** : cleanup of agents modified in Phase 2
  - stop inferring & sending `span.destination.service.resource` for APM-server > 8.3
  - stop computing dropped spans metrics for `span.destination.service.resource`
  
TODO: do we need to make the agents compatible with older versions of APM servers ?
If yes, then it means that we need to keep agents computing and always sending `destination.service.resource`.

### Examples

1. Database call to a `mysql` server without database instance name
2. Database call to a `mysql` server on the `my-instance` database
3. Send message on `rabbitmq` server without queue
4. Send message on `rabbitmq` server on the `my-queue` queue

| Span field                              | #1      | #2            | #3          | #4                  |
|-----------------------------------------|---------|---------------|-------------|---------------------|
| `span.type`                             | `db`    | `db`          | `messaging` | `messaging`         |
| `span.subtype`                          | `mysql` | `mysql`       | `rabbitmq`  | `rabbitmq`          |
| `span.context.service.target.type`      | `mysql` | `mysql`       | `rabbitmq`  | `rabbitmq`          |
| `span.context.service.target.name`      |         | `my-db`       |             | `my-queue`          |
| `span.destination.service.resource` (*) | `mysql` | `mysql/my-db` | `rabbitmq`  | `rabbitmq/my-queue` |

(*) Value is inferred and sent by APM agents in Phase 2, inferred on APM Server once Phase 3 is complete

TODO : only for exit spans custom : see who created the spec for clarification

## APM Agents

There are a few features in APM Agents relying on `span.destination.service.resource`:

- Dropped spans metrics
- Compressed spans
- Agent API might provide a way to manually set the `span.destination.service.resource`, if such API exists we should provide an equivalent to enable setting `span.service.target.type` and `span.service.target.name`.

### Phase 2

## APM Server

The following features rely on `span.destination.service.resource` field:

- APM Map
- APM Services Dependencies

As a result, we need to make APM server handle the compatibility with those for both existing and new agents.

### Phase 1

TODO

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

TODO:

#### OTel intake compatibility

#### Jaeger intake compatibility ?