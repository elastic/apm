## Span destination

The span destination information is relevant for exit spans and helps to identify the downstream service.
This information is used for the [service map](https://www.elastic.co/guide/en/kibana/current/service-maps.html),
the [dependencies table](https://www.elastic.co/guide/en/kibana/current/service-overview.html#service-span-duration) in the service overview,
and the [APM SIEM integration](https://www.elastic.co/blog/elastic-apm-7-6-0-released).

### Destination service fields

Spans representing an external call MUST have `context.destination.service` information.
If the span represents a call to an in-memory database, the information SHOULD still be set.

Agents SHOULD have a generic component used in all tests that validates that the destination information is present for exit spans.
Rather than opting into the validation, the testing should provide an opt-out if,
for whatever reason, the destination information can't or shouldn't be collected for a particular exit span.

#### `context.destination.service.name`

ES field: `span.destination.service.name`

The identifier for the destination service.

**Usage**

Currently, this field is not used anywhere within the product.
The original intent was to use it as a display name of a service in the service map.

**Value**

For HTTP, use scheme, host, and non-default port (e.g. `http://elastic.co`, `http://apm.example.com:8200`).
For anything else, use `span.subtype` (e.g. `postgresql`, `elasticsearch`).
However, individual sub-resources of a service, such as the name of a message queue, should not be added.

If unset, agents SHOULD automatically set the field on span end for external spans:
```
if      context.db?.instance         "${span.subtype}/${context.db?.instance}"
else if context.message?.queue?.name "${span.subtype}/${context.message.queue.name}"
else    span.subtype
```

#### `context.destination.service.resource`

ES field: `span.destination.service.resource`

Identifies unique destinations for each service.

**Usage**

Each unique resource will result in a node on the [service map](https://www.elastic.co/guide/en/kibana/current/service-maps.html).
Also, APM Server will roll up metrics based on the resource.
These metrics are currently used for the [dependencies table](https://www.elastic.co/guide/en/kibana/current/service-overview.html#service-span-duration)
on the service overview page.
There are plans to use the service destination metrics in the service map, too.

The metrics are calculated based on the (head-based) sampled span documents that are sent to APM Server.
That's why agents have to send the [`sample_rate`](tracing-sampling.md#effect-on-metrics)
attribute for transactions and spans:
It is used by APM Server to extrapolate the service destination metrics based on the (head-based) sampled spans.

**Cardinality**

To avoid a huge impact on storage requirements for metrics,
and to not "spam" the service map with lots of fine-grained nodes,
the cardinality has to be kept low.
However, the cardinality should not be too low, either,
so that different clusters, instances, and queues can be displayed separately in the service map.

The cardinality should be the same or higher as `span.destination.service.name`.
Higher, if there are individual sub-resources for a service, such as individual queues for a message broker.
Same cardinality otherwise.

**Value**

Usually, the value is just the `span.subtype`.
For HTTP, this is the host and port (see the [HTTP spec](tracing-instrumentation-http.md#destination) for more details).
The specs for the specific technologies will have more information on how to construct the value for `context.destination.service.resource`.

#### `context.destination.service.type`

ES field: `span.destination.service.type`

Type of the destination service, e.g. `db`, `elasticsearch`.
Should typically be the same as `span.type`.

If unset, agents SHOULD automatically set `context.destination.service.type` based on `span.type` on span end for external spans.  

**Usage**

Currently, this field is not used anywhere within the product.
It was originally intended to be used to display different icons on the service map.

### Destination fields

These fields are used within the APM/SIEM integration.
They don't play a role for service maps.

Spans representing an external call SHOULD have `context.destination` information if it is easy to gather.

Examples when the effort of capturing the address and port is not justified:
* When the underlying protocol-layer code is not readily available in the instrumented code.
* When the instrumentation captures the exit event,
  but the actual client is not bound to a specific connection (e.g. a client that does load balancing).

#### `context.destination.address`

ES field: [`destination.address`](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#_destination_field_details)

Address is the destination network address: hostname (e.g. `localhost`), FQDN (e.g. `elastic.co`), IPv4 (e.g. `127.0.0.1`) IPv6 (e.g. `::1`)

#### `context.destination.port`

ES field: [`destination.port`](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#_destination_field_details)

Port is the destination network port (e.g. 443)
