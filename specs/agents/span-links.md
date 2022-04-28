## Span Links

A Span or Transaction MAY link to zero or more other Spans/Transactions that are causally related.

Example use-cases for Span Links:

1. When a single transaction represents the batch processing of several messages, the agent is able to link back to the traces that have produced the messages.
2. When the agent receives a `traceparent` header from outside a trust boundary, it [can restart the trace](trace_continuation.md) (creating a different trace id with its own sampling decision) and link to the originating trace.
3. Close gap for the OTLP intake - [OTel's specification of span links](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/overview.md#links-between-spans)

Spans and Transactions MUST collect links in the `links` array with the following fields on each item:
- `trace_id`: the id of the linked trace.
- `span_id`: the id of the linked span or transaction.

Example:

```
"links": [
  {"trace_id": "traceId1", "span_id": "spanId1"},
  {"trace_id": "traceId2", "span_id": "spanId2"},
]
```

### API

Agents MAY provide a public API to add span links at span/transaction creation.
A use-case for user's manually adding span links is for [batch message processing](tracing-instrumentation-messaging.md#batch-message-processing)
that the APM agent does not or cannot instrument. (For some agents it would be
a burden to internally support span links and *not* expose the API publicly.)

If provided, the API SHOULD be written such that user code is not broken if/when
support for span link *attributes* is added in the future.

If provided, the API and semantics SHOULD be compatible with the
[OpenTelemetry specification on specifying span links](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#specifying-links). A compatible API will facilitate
[OpenTelemetry bridge](trace-api-otel.md) support. OpenTelemetry requirements:

- The public API MUST NOT allow adding span links *after* span creation.
- Links SHOULD preserve the order in which they are set.
