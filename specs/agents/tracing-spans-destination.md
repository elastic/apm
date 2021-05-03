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

**Deprecated**

This field is deprecated and scheduled to be removed.

This field is not used anywhere within the product,
and we don't have plans to do so.
However, we can't just remove it as it's a required field in the intake API.

Future versions of APM Server will remove the field from the intake API and drop it if sent by agents.
Agents MAY omit the field when sending spans to an APM Server that doesn't require the field.

**Value**

Agents MUST NOT manually set this field.
Agents MUST NOT offer a non-deprecated public API to set it.

The value is automatically set on span end, after the value of `context.destination.service.resource` has been determined.
```groovy
if (context.destination?.service?.resource) context.destination.service.name = subtype ?: type
```

The change to automatically set the field mainly has an effect on HTTP and gRPC spans that used to set the value to host and non-default port.
As the field is not used anywhere, and we want to remove it from the span documents in the future, that's fine.

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

**API**

Agents SHOULD offer a public API to set this field so that users can customize the value if the generic mapping is not sufficient.
User-supplied values MUST have the highest precedence.

To allow for automatic inference,
without users having to specify any destination field,
agents SHOULD offer a dedicated API to start an exit span.
This API sets the `exit` flag to `true` and returns `null` or a noop span in case the parent already represents an `exit` span.

**Value**

For all exit spans,
agents MUST infer the value of this field based on properties that are set on the span.

This is how to determine whether a span is an exit span:
```groovy
exit = exit || context.destination || context.db || context.message
```

For each exit span that does not have a value for `context.destination.service.resource`,
agents MUST run this logic to infer the value.
```groovy
if      (context.db?.instance)         "${subtype ?: type}/${context.db?.instance}"
else if (context.message?.queue?.name) "${subtype ?: type}/${context.message.queue.name}"
else if (context.http?.url)            "${context.http.url.host}:${context.http.url.port}"
else                                   subtype ?: type
```

The inference of `context.destination.service.resource` SHOULD be implemented in a central place within the agent,
such as an on-span-end-callback or the setter of a dependant property,
rather than being implemented for each individual library integration/instrumentation.

For specific technologies, the field MAY be set non-centrally.
However, updating the generic inference logic SHOULD be preferred, if feasible.
Setting the value within a specific library integration/instrumentation is perfectly fine is if there's only one canonical library for it.
Examples: gRPC and cloud-provider specific backends.

#### `context.destination.service.type`

ES field: `span.destination.service.type`

Type of the destination service.

**Deprecated**

This field is deprecated and scheduled to be removed.

This field is not used anywhere within the product,
and we don't have plans to do so.
However, we can't just remove it as it's a required field in the intake API.

Future versions of APM Server will remove the field from the intake API and drop it if sent by agents.
Agents MAY omit the field when sending spans to an APM Server that doesn't require the field.

**Value**

Agents MUST NOT manually set this field.
Agents MUST NOT offer a non-deprecated public API to set it.

The value is automatically set on span end, after the value of `context.destination.service.resource` has been determined.
```groovy
if (context.destination?.service?.resource) context.destination.service.type = type
```

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
