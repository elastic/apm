## Span Links

A Span or Transaction MAY link to zero or more other Spans/Transactions that are causally related.

Example use-cases for Span Links:

1. When a single transaction represents the batch processing of several messages, the agent SHOULD be able to link back to the traces that have produced the messages.
2. When the agent receives a `traceparent` header from outside a trust boundary, it SHOULD restart the trace (creating a different trace id with its own sampling decision) and link to the originating trace.
3. Close gap for the OTLP intake - [OTel's specification of span links](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/overview.md#links-between-spans)

Spans and Transactions MUST collect links in the `links` array with the following fields on each item:
- `trace.id`: the id of the linked trace.
- `span.id`: the id of the linked span or transaction.

Example:

```
"links": [
  {"trace": {"id": "traceId1"}, "span": {"id": "spanId1"}},
  {"trace": {"id": "traceId2"}, "span": {"id": "spanId2"}},
]
```

## Trace Continuation

We can expect incoming requests into an application with our agent which contains a `traceparent` header added by a 3rd party component. In this situation we end up with traces where part of the trace is outside of our system.

In order to handle this properly, the agent SHOULD offer several trace continuation strategies.

The agent SHOULD offer a configuration called `trace_continuation_strategy` with the following values and behavior:

- `continue_always`: The agent takes the `traceparent` header as it is and applies it to the new transaction.
- `restart_always`: The agent always creates a new trace with a new trace id. In this case the agent MUST create a link in the new transaction pointing to the original trace.
- `restart_external`: The agent first checks the `tracestate` header. If the header contains the `es` vendor flag, it's treated as internal, otherwise (including the case when the `tracestate` header is not present) it's treated as external. In case of external calls the agent MUST create a new trace with a new trace id and MUST create a link in the new transaction pointing to the original trace.

The default is `continue_always`. 