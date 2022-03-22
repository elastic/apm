## Span Links

A Span or Transaction MAY link to zero or more other Spans/Transactions that are causally related.

Example use-cases for Span Links:

1. When a single transaction represents the batch processing of several messages, the agent is able to link back to the traces that have produced the messages.
2. When the agent receives a `traceparent` header from outside a trust boundary, it can restart the trace (creating a different trace id with its own sampling decision) and link to the originating trace.
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