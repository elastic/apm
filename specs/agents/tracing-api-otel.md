## OpenTelemetry API (Tracing)

[OpenTelemetry](https://opentelemetry.io) (OTel in short) provides a vendor-neutral API that allows to capture tracing, logs and metrics data.

Agents may provide a bridge implementation of OpenTracing Tracing API following this specification.

Bridging here means that for each OTel span created with the API, a native span/transaction will be created and sent to APM server.

From the perspective of the application code calling the OTel API, the delegation to a native span/transaction is transparent.
Also, this means that any OTel processors will be bypassed and ignored by the bridge.

### Spans and Transactions

OTel only defines Spans, whereas Elastic APM relies on both Spans and Transactions.
OTel allows users to provide the _remote context_ when creating a span, which is equivalent to providing a parent to a transaction or span,
it also allows to provide a (local) parent span.

As a result, when creating Spans through OTel API with a bridge, agents must implement the following algorithm:

```javascript
// otel_span contains the properties set through the OTel API
span_or_transaction = null;
if (otel_span.remote_contex != null) {
    span_or_transaction = createTransactionWithParent(otel_span.remote_context);
} else if (otel_span.parent == null) {
    span_or_transaction = createRootTransaction();
} else {
    span_or_transaction = createSpanWithParent(otel_span.parent);
}
```

### Span Kind

OTel spans have an `SpanKind` property ([specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#spankind)) which is close but not strictly equivalent to our definition of spans and transactions.

For both transactions and spans, an optional `otel.span_kind` property will be provided by agents when set through
the OTel API.
This value should be stored into Elasticsearch documents to preserve OTel semantics and help future OTel integration.

Possible values are `CLIENT`, `SERVER`, `PRODUCER`, `CONSUMER` and `INTERNAL`, refer to [specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#spankind) for details on semantics.

When `otel.span_kind` is not provided by the agent, APM Server should infer it using the following algorithm:

```javascript
span_kind = null;
if (isTransaction(item)) {
    if (item.type == "messaging") {
        span_kind = "CONSUMER";
    } else if (item.type == "request") {
        span_kind = "SERVER";
    }
} else {
    // span
    if (item.type == "external" || item.type == "storage") {
        span_kind = "CLIENT";
    }
}

if (span_kind == null) {
    span_kind = "INTERNAL";
}

```

### Attributes mapping

OTel relies on key-value pairs for span attributes.
Keys and values are protocol-specific and are defined in [semantic convention](https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions) specification.

In order to minimize the mapping complexity in agents, most of the mapping between OTel attributes and agent protocol will be delegated to APM server:
- All OTel span attributes should be captured as-is and written to agent protocol.
- APM server will handle the mapping between OTel attributes and their native transaction/spans equivalents
- Some native span/transaction attributes will still require mapping within agents for [compatibility with existing features](#compatibility-mapping)

OpenTelemetry attributes should be stored in `otel.attributes` as a flat key-value pair mapping added to `span` and `transaction` objects:
```json
{
  // [...] other span/transaction attributes
  "otel": {
    "span_kind": "CLIENT",
    "attributes": {
      "db.system": "mysql",
      "db.statement": "SELECT * from table_1"
    }
  }
}
```

When the APM server version does not support `otel.attributes` property, agents should use `labels` as fallback with OTel attribute
name as key.

When the APM server supports `otel.attributes` property, the server-side mapping should be identical to the one
that is applied to handle native OpenTelemetry Protocol (OTLP) intake.

### Compatibility mapping

Agents should ensure compatibility with the following features:
- breakdown metrics
- [dropped spans statistics](handling-huge-traces/tracing-spans-dropped-stats.md)
- [compressed spans](handling-huge-traces/tracing-spans-compress.md)

As a consequence, agents have to infer and provide values for the following attributes:
- `transaction.name`
- `transaction.type`
- `span.name`
- `span.type`
- `span.subtype`
- `span.name`
- `span.destination.service.resource`

### Active Spans and Context

OTel has the concept of "active context", which is implemented as a key-value map and is used for local context
propagation implicitly through thread-locals or explicitly through API.

Our agents may not have a similar abstraction and only have the currently active span or transaction stored into a thread-local stack.
Making OTel span active means adding a reference to it in the current context, deactivating is restoring the context
before activation.

As a result, a proper bridge implementation should ensure transparent interoperability between Elastic and OTel spans from their respective APIs
- When an Elastic span is active, the OTel current context API should have the Elastic span as current
- When an OTel context is activated, the OTel current context API should provide access to it (likely stored as a thread-local).
- Activating an OTel span on top of an Elastic span should behave exactly as if the underlying span was created using OTel API.
- Activating an Elastic span on top of an OTel span should behave like if the underlying span was created from Elastic API.
