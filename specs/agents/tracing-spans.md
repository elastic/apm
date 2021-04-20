## Spans

The agent should also have a sense of the most common libraries for these and instrument them without any further setup from the app developers.

### Span ID fields

Each span object will have an `id`. This is generated for each transaction and
span, and is 64 random bits (with a string representation of 16 hexadecimal
digits).

Spans will also have a `transaction_id`, which is the `id` of the current
transaction. While not necessary for distributed tracing, this inclusion allows
for simpler and more performant UI queries.

### Span outcome

The `outcome` property denotes whether the span represents a success or failure, it is used to compute error rates
to calling external services (exit spans) from the monitored application. It supports the same values as `transaction.outcome`.

This property is optional to preserve backwards compatibility, thus it is allowed to omit it or use a `null` value.

If an agent does not report the `outcome` property (or use a `null` value), then the outcome will be set according to HTTP
response status if available, or `unknown` if not available. This allows a server-side fallback for existing
agents that might not report `outcome`.

While the transaction outcome lets you reason about the error rate from the service's point of view,
other services might have a different perspective on that.
For example, if there's a network error so that service A can't call service B,
the error rate of service B is 100% from service A's perspective.
However, as service B doesn't receive any requests, the error rate is 0% from service B's perspective.
The `span.outcome` also allows reasoning about error rates of external services.

The following protocols get their outcome from protocol-level attributes:

- [gRPC](tracing-instrumentation-grpc.md#outcome)
- [HTTP](tracing-instrumentation-http.md#outcome)

For other protocols, we can default to the following behavior:

- `failure` when an error is reported
- `success` otherwise

Also, while we encourage most instrumentations to create spans that have a deterministic outcomes, there are a few 
examples for which we might still have to report `unknown` outcomes to prevent reporting any misleading information:
- Inferred spans created through a sampling profiler: those are not exit spans, we can't know if those could be reported
as either `failure` or `outcome` due to inability to capture any errors.
- External process execution, we can't know the `outcome` until the process has exited with an exit code.

### Outcome API

Agents should expose an API to manually override the outcome.
This value must always take precedence over the automatically determined value.
The documentation should clarify that spans with `unknown` outcomes are ignored in the error rate calculation.

### Span stack traces

Spans may have an associated stack trace, in order to locate the associated source code that caused the span to occur. If there are many spans being collected this can cause a significant amount of overhead in the application, due to the capture, rendering, and transmission of potentially large stack traces. It is possible to limit the recording of span stack traces to only spans that are slower than a specified duration, using the config variable `ELASTIC_APM_SPAN_FRAMES_MIN_DURATION`.

### Span count

When a span is started a counter should be incremented on its transaction, in order to later identify the _expected_ number of spans. In this way we can identify data loss, e.g. because events have been dropped, or because of instrumentation errors.

To handle edge cases where many spans are captured within a single transaction, the agent should enable the user to start dropping spans when the associated transaction exeeds a configurable number of spans. When a span is dropped, it is not reported to the APM Server, but instead another counter is incremented to track the number of spans dropped. In this case the above mentioned counter for started spans is not incremented.

```json
"span_count": {
  "started": 500,
  "dropped": 42
}
```

Here's how the limit can be configured for [Node.js](https://www.elastic.co/guide/en/apm/agent/nodejs/current/agent-api.html#transaction-max-spans) and [Python](https://www.elastic.co/guide/en/apm/agent/python/current/configuration.html#config-transaction-max-spans).

### Exit spans

Exit spans are spans that describe a call to an external service,
such as an outgoing HTTP request or a call to a database.

Exit spans MUST not have child spans that have a different `type` and `subtype`.
For example, when capturing a span representing a query to Elasticsearch,
there should not be an HTTP span for the same operation.
Doing that would make [breakdown metrics](https://github.com/elastic/apm/blob/master/specs/agents/metrics.md#transaction-and-span-breakdown)
less meaningful,
as most of the time would be attributed to `http` instead of `elasticsearch`.

Agents MAY add information from the lower level transport to the exit span, though.
For example, the HTTP `context.http.status_code` may be added to an `elasticsearch` span.

Exit spans MAY have child spans that have the same `type` and `subtype`.
For example, an HTTP exit span may have child spans with the `action` `request`, `response`, `connect`, `dns`.
These spans MUST NOT have any destination context, so that there's no effect on destination metrics.

Agents don't need to prevent the creation of exit child spans via the public API.
Agents MAY implement internal APIs to create an exit span (such as `Span::createExitSpan`) that flags a span as an exit span (`exit=true`).
Returning `null` from `Span::createExitSpan` when the curren span is flagged with `exit=true` can help to avoid creating nested exit spans.
