## Trace Continuation

The `traceparent` header of requests that are traced with our agents might have been added by a 3rd party component.

This situation becomes more and more common as the w3c trace context gets adopted. In such cases we can end up with traces where part of the trace is outside of our system.

In order to handle this properly, the agent SHOULD offer several trace continuation strategies.

The agent SHOULD offer a configuration called `trace_continuation_strategy` with the following values and behavior:

- `continue`: The agent takes the `traceparent` header as it is and applies it to the new transaction.
- `restart`: The agent always creates a new trace with a new trace id. In this case the agent MUST create a [span link](span-links.md) in the new transaction pointing to the original traceparent.
- `restart_external`: The agent first checks the `tracestate` header. If the header contains the `es` vendor flag, it's treated as internal, otherwise (including the case when the `tracestate` header is not present) it's treated as external. In case of external calls the agent MUST create a new trace with a new trace id and MUST create a link in the new transaction pointing to the original trace.

The default is `continue`.