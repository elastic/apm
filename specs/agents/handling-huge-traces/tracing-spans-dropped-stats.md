# Collecting statistics about dropped spans

To still retain some information about dropped spans (for example due to [`transaction_max_spans`](tracing-spans-limit.md) or [`exit_span_min_duration`](tracing-spans-drop-fast-exit.md)),
agents SHOULD collect statistics on the corresponding transaction about dropped spans.
These statistics MUST only be sent for sampled transactions.

Agents SHOULD only collect these statistics for exit spans that have a non-empty `service.target.type` (and `service.target.name`),
or a non-empty `destination.service.resource` if they don´t use [Service Target fields](../tracing-spans-service-target.md)

This feature used to rely on the deprecated `destination.service.resource` field, which is replaced by `service.target.type`
and `service.target.name`.
However, in order to preserve compatibility, we still need to provide its value in dropped spans metrics.

## Use cases

This allows APM Server to consider these metrics for the service destination metrics.
In practice,
this means that the service map, the dependencies table,
and the backend details view can show accurate throughput statistics for backends like Redis,
even if most of the spans are dropped.

## Data model

This is an example of the statistics that are added to the `transaction` events sent via the intake v2 protocol.

```json
{
  "dropped_spans_stats": [
    {
      "destination_service_resource": "example.com:443",
      "service_target_type": "http",
      "service_target_name": "example.com:443",
      "outcome": "failure",
      "duration.count": 28,
      "duration.sum.us": 123456
    },
    {
      "destination_service_resource": "mysql",
      "service_target_type": "mysql",
      "outcome": "success",
      "duration.count": 81,
      "duration.sum.us": 9876543
    }
  ]
}
```

### Compatibility

When the `service_target_*` fields are provided, APM server has to use those fields to identify the destination.

When the `service_target_*` fields are not provided, APM server has to infer equivalent values using the algorigthm
described in [Service Target Fields](../tracing-spans-service-target.md).

## Limits

To avoid the structures from growing without bounds (which is only expected in pathological cases),
agents MUST limit the size of the `dropped_spans_stats` to 128 entries per transaction.
Any entries that would exceed the limit are silently dropped.

## Effects on destination service metrics

As laid out in the [span destination spec](tracing-spans-destination.md#contextdestinationserviceresource),
APM Server tracks span destination metrics.
To avoid dropped spans to skew latency metrics and cause throughput metrics to be under-counted,
APM Server will take `dropped_spans_stats` into account when tracking span destination metrics.
