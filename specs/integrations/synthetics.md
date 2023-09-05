## Synthetics Integration

Synthetic monitors play a crucial role in periodically checking the status of your services and applications on a global scale. General documentation about synthetic monitors can be found in
[Synthetics getting started page](https://www.elastic.co/guide/en/observability/current/synthetics-get-started.html).

This integration goes in to more detail about how the sythetics monitors would
be correlated with the APM traces. Synthetics traces can be categorized in to two
main types
  1. HTTP checks - These have one-one mapping with APM transactions
  2. Browser checks - These have a one-to-many mapping with APM transactions

### Correlation

The Synthetics agent takes the responsibility of creating the [`traceparent`](../agents/tracing-distributed-tracing.md#trace_id-parent_id-and-traceparent) header for each outgoing network request associated with a test during every monitor execution.

- `trace.id` and `parent.id`
  - outgoing requests that are being explicity traced by the synthetics agent
     will have the `parent.id` and `trace.id` as part of the trace context.
  - must be unique for each step for a browser monitor
  - must be unique for a http monitor
- `sampled` Flag
  - used to control the sampling decision for all the downstream services.
  - 100% sampling when tracing is enabled

These correlation values would be applicable even if the downstream services are traced by
OpenTelemetry(OTEL)-based agents.

### Identifying Synthetics trace

Synthetics monitor executions creates `rootless traces` as these traces are not
reported to the APM server. To overcome this limitation on the APM UI, we need
to identify the synthetics traces and explicity link them  to the Synthetics
waterfall view. 

- `http.headers.user-agent`:
  - Contains `Elastic/Synthetics` for all outgoing requests from Synthetis based monitors.

When a trace is confirmed to be originated from Synthetics-based monitors, the
Trace Explorer view can be linked back to the Synthetics waterfall view.

- `/app/synthetics/link-to/<trace.id>`
   - used to link back the explicit browser waterfall step on the Synthetics UI.