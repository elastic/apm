## Span destination

The span destination information is relevant for exit spans and helps to identify the downstream service.
This information is used for the [service map](https://www.elastic.co/guide/en/kibana/current/service-maps.html),
the [dependencies table](https://www.elastic.co/guide/en/kibana/current/service-overview.html#service-span-duration) in the service overview,
and the [APM SIEM integration](https://www.elastic.co/blog/elastic-apm-7-6-0-released).

### Destination service fields

In `context.destination.service`, `_.name` and `_.type` fields are deprecated and replaced by `context.service.target.*` fields.
See [related specification](tracing-spans-service-target.md) for more details.

The only field still required is `context.destination.service.resource` until APM server is able to infer it.

#### Deprecated fields

- `context.destination.service.name` : deprecated but still required in protocol, thus value should be an empty string `""`.
- `context.destination.service.type` : deprecated but still required in protocol, thus value should be an empty string `""`.

Agents MUST NOT manually set these fields.
Agents MUST NOT offer non-deprecated public APIs to set them.

The intake JSON spec until 7.14.0 requires the deprecated fields to be present if `context.destination.service.resource` is set.
Future versions of APM Server will remove the fields from the intake API and drop it if sent by agents.

Agents MAY omit the deprecated fields when sending spans to an APM Server version >= 7.14.0 .
Otherwise, the field MUST be serialized as an empty string if `context.destination.service.resource` is set.
Both options result in the fields being omitted from the Elasticsearch document.

#### Destination resource

- `context.destination.service.resource` :
  - ES field: `span.destination.service.resource`
  - Identifies unique destinations for each service.
  - value should be inferred from `context.service.target.*` fields
  - required for compatibility with existing features (Service Map, Dependencies) that rely on it
  - might become optional in the future once APM server is able to infer the value from `context.service.target.*` fields.

Spans representing an external call MUST have `context.destination.service` information.
If the span represents a call to an in-memory database, the information SHOULD still be set.

Agents SHOULD have a generic component used in all tests that validates that the destination information is present for exit spans.
Rather than opting into the validation, the testing should provide an opt-out if,
for whatever reason, the destination information can't or shouldn't be collected for a particular exit span.

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

Agents SHOULD offer a public API to set this field so that users can customize the value if the generic mapping is not
sufficient. If set to `null` or an empty value, agents MUST omit the `span.destination.service` field altogether, thus
providing a way to manually disable the automatic setting/inference of this field (e.g. in order to remove a node
from a service map or an external service from the dependencies table).
A user-supplied value MUST have the highest precedence, regardless if it was set before or after the automatic setting is invoked.

**Value**

For all [exit spans](tracing-spans.md#exit-spans), unless the `context.destination.service.resource` field was set by the user to `null` or an empty
string through API, agents MUST infer the value of this field based on properties that are set on the span.

If no value is set to the `context.destination.service.resource` field, the logic for automatically inferring
it MUST be the following:

Q3: Though above it is says "value should be inferred from `context.service.target.*` fields", this pseudo-code does not consider service.target. Should this be updated to calculate from service.target?

```groovy
if (context.db)
  if (context.db.instance)
    "${subtype ?: type}/${context.db.instance}"
  else
    subtype ?: type
else if (context.message)
  if (context.message.queue?.name)
    "${subtype ?: type}/${context.message.queue.name}"
  else
    subtype ?: type
else if (context.http?.url)
  if (context.http.url.port > 0)
    "${context.http.url.host}:${context.http.url.port}"
  else if (context.http.url.host)
    context.http.url.host
else
  subtype ?: type
```

If an agent API was used to set the `context.destination.service.resource` to `null` or an empty string, agents MUST
omit the `context.destination.service` field from the reported span event.

The inference of `context.destination.service.resource` SHOULD be implemented in a central place within the agent,
such as an on-span-end-callback or the setter of a dependant property,
rather than being implemented for each individual library integration/instrumentation.

For specific technologies, the field MAY be set non-centrally.
However, updating the generic inference logic SHOULD be preferred, if feasible.
Setting the value within a specific library integration/instrumentation is perfectly fine if there's only one canonical library for it.
Examples: gRPC and cloud-provider specific backends.

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

Agents MAY offer a public API to set this field so that users can override the automatically discovered one.
This includes the ability to set `null` or empty value in order to unset the automatically-set value.
A user-supplied value MUST have the highest precedence, regardless of whether it was set before or after the automatic setting is invoked.

#### `context.destination.port`

ES field: [`destination.port`](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#_destination_field_details)

Port is the destination network port (e.g. 443)

Agents MAY offer a public API to set this field so that users can override the automnatically discovered one.
This includes the ability to set a non-positive value in order to unset the automatically-set value.
A user-supplied value MUST have the highest precedence, regardless of whether it was set before or after the automatic setting is invoked.
