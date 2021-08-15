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

Spans may have an associated stack trace, in order to locate the associated
source code that caused the span to occur. If there are many spans being
collected this can cause a significant amount of overhead in the application,
due to the capture, rendering, and transmission of potentially large stack
traces. It is possible to limit the recording of span stack traces to only
spans that are slower than a specified duration, using the config variable
`span_stack_trace_min_duration`. (Previously
`span_frames_min_duration`.)

#### `span_stack_trace_min_duration` configuration

Sets the minimum duration of a span for which stack frames/traces will be
captured.

This values for this option are case-sensitive.

|                |   |
|----------------|---|
| Valid options  | [duration](configuration.md#configuration-value-types) |
| Default        | `5ms` (soft default, agents may modify as needed) |
| Dynamic        | `true` |
| Central config | `true` |

A negative value will result in never capturing the stack traces.

A value of `0` (regardless of unit suffix) will result in always capturing the
stack traces.

A non-default value for this configuration option should override any value
set for the deprecated `span_frames_min_duration`.

### Exit spans

Exit spans are spans that describe a call to an external service,
such as an outgoing HTTP request or a call to a database.

A span is considered an exit span if it has explicitly been marked as such; a
span's status should not be inferred.

#### Child spans of exit spans

Exit spans MUST not have child spans that have a different `type` or `subtype`.
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

Most agents would want to treat exit spans as leaf spans, though.
This brings the benefit of being able to [compress](handling-huge-traces/tracing-spans-compress.md) repetitive exit spans,
as span compression is only applicable to leaf spans.

Agents MAY implement mechanisms to prevent the creation of child spans of exit spans.
For example, agents MAY implement internal (or even public) APIs to mark a span as an exit or leaf span.
Agents can then prevent the creation of a child span of a leaf/exit span.
This can help to drop nested HTTP spans for instrumented calls that use HTTP as the transport layer (for example Elasticsearch).

#### Context propagation

When tracing an exit span, agents SHOULD propagate the trace context via the underlying protocol wherever possible.

Example: for Elasticsearch requests, which use HTTP as the transport, agents SHOULD add `traceparent` headers to the outgoing HTTP request.

This means that such spans cannot be [compressed](handling-huge-traces/tracing-spans-compress.md) if the context has 
been propagated, because the `parent.id` of the downstream transaction may refer to a span that's not available.
For now, the implication would be the inability to compress HTTP spans. Should we decide to enable that in the future, 
following are two options how to do that:
- Add a denylist of span `type` and/or `subtype` to identify exit spans of which underlying protocol supports context propagation by default. 
For example, such list could contain `type == storage, subtype == s3`, preventing context propagation at S3 queries, even though those rely on HTTP/S.
- Add a list of child IDs to compressed exit spans that can be used when looking up `parent.id` of downstream transactions.
