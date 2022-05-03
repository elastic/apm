# Collecting statistics about dropped spans

To still retain some information about dropped spans (for example due to [`transaction_max_spans`](tracing-spans-limit.md) or [`exit_span_min_duration`](tracing-spans-drop-fast-exit.md)),
agents SHOULD collect statistics on the corresponding transaction about dropped spans.
These statistics MUST only be sent for sampled transactions.

Agents SHOULD only collect these statistics for exit spans that have a non-empty `destination.service.resource`.

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
      "target_service_type": "http",
      "target_service_name": "example.com:443",
      "outcome": "failure",
      "duration.count": 28,
      "duration.sum.us": 123456
    },
    {
      "destination_service_resource": "mysql",
      "target_service_type": "mysql",
      "outcome": "success",
      "duration.count": 81,
      "duration.sum.us": 9876543
    }
  ]
}
```

## Limits

To avoid the structures from growing without bounds (which is only expected in pathological cases),
agents MUST limit the size of the `dropped_spans_stats` to 128 entries per transaction.
Any entries that would exceed the limit are silently dropped.

## Effects on destination service metrics

As laid out in the [span destination spec](tracing-spans-destination.md#contextdestinationserviceresource),
APM Server tracks span destination metrics.
To avoid dropped spans to skew latency metrics and cause throughput metrics to be under-counted,
APM Server will take `dropped_spans_stats` into account when tracking span destination metrics.
