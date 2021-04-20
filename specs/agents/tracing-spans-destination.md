## Span destination

Spans representing an external call MUST have `context.destination` information.
If the span represents a call to an in-memory database, the information SHOULD still be set.

Agents SHOULD have a generic component used in all tests that validates that the destination information is present for exit spans.
Rather than opting into the validation, the testing should provide an opt-out if,
for whatever reason, the destination information can't or shouldn't be collected for a particular exit span.

### Destination service fields

#### `context.destination.service.name`

ES field: `span.destination.service.name`

The identifier for the destination service.

For HTTP, use scheme, host, and non-default port (e.g. `http://elastic.co`, `http://apm.example.com:8200`).
For anything else, use `span.subtype` (e.g. `postgresql`, `elasticsearch`).

**Usage**

Currently, this field is not anywhere within the product.

#### `context.destination.service.resource`

ES field: `span.destination.service.resource`

Identifies unique destinations for each service.

**Usage**

Each unique resource will result in node on the service map.
Also, APM Server will roll up metrics based on the resource.
These metrics are currently used for the [dependencies table](https://www.elastic.co/guide/en/kibana/current/service-overview.html#service-span-duration)
on the service overview page.
There are plans to use the service desination metrics in the service map, too.

The metrics are calculated based on the (head-based) sampled span documents that are sent to APM Server.
That's why agents have to send the [`sample_rate`](tracing-sampling.md#effect-on-metrics)
attribute for transactions and spans:
It is used by APM Server to extrapolate the service destination metrics based on the (head-based) sampled spans.

**Cardinality**

To avoid a huge impact on storage requirements for metrics,
and to not "spam" the service map with lots of fine-grained nodes,
the cardinality has to be kept low.
However, the cardinality should, not be too low, either,
so that different clusters, instances, or queues can be displayed separately in the service map.

Generally, the value would look something like `${span.type}/${cluster}`.
The specs for the specific technologies will have more information on how to construct the value for `context.destination.service.resource`.

#### `context.destination.service.type`

ES field: `span.destination.service.type`

Type of the destination service, e.g. `db`, `elasticsearch`.
Should typically be the same as `span.type`.
Used to displaying different icons on the service map. (TODO confirm)

### Destination fields

These fields are used within the APM/SIEM integration.
They don't play a role for service maps.

#### `context.destination.address`

ES field: [`destination.address`](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#_destination_field_details)

Address is the destination network address: hostname (e.g. `localhost`), FQDN (e.g. `elastic.co`), IPv4 (e.g. `127.0.0.1`) IPv6 (e.g. `::11`)

#### `context.destination.port`

ES field: [`destination.port`](https://www.elastic.co/guide/en/ecs/current/ecs-destination.html#_destination_field_details)

Port is the destination network port (e.g. 443)
