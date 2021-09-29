## OpenTelemetry API (Tracing)

[OpenTelemetry](https://opentelemetry.io) (OTel in short) provides a vendor-neutral API that allows to capture tracing, logs and metrics data.

Agents may provide a bridge implementation of OpenTracing Tracing API following this specification.

Bridging here means that for each OTel span created with the API, a native span/transaction will be created and sent to APM server.

From the perspective of the application code calling the OTel API, the delegation to a native span/transaction is transparent.
Also, this means that any OTel processors will be bypassed and ignored by the bridge.

### Attributes mapping

OTel relies on key-value pairs for span attributes. Keys and values are protocol-specific and are defined in [semantic convention](https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions) specification.

In order to minimize the mapping complexity in agents, most of the mapping between OTel attributes and agent protocol will be delegated to APM server:
- All OTel span attributes should be captured as-is and written to agent protocol.
- APM server will handle the mapping between OTel attributes and their native transaction/spans equivalents
- Some native span/transaction attributes will still require mapping within agents for [compatibility with existing features](#compatibility-mapping)

OpenTelemetry attributes should be stored in `otel.attributes` as a flat key-value pair mapping added to `span` and `transaction` objects:
```json
{
  // [...] other span/transaction attributes
  "otel": {
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
