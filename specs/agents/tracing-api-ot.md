## OpenTracing API

[OpenTracing](https://opentracing.io) provides a vendor-neutral API for tracing. It is now deprecated in favor
of [OpenTelemetry](https://opentelemetry.io).

Support for OpenTelemetry is defined in [OpenTelemetry API bridge](tracing-api-otel.md).

Agents may provide a bridge implementation of OpenTracing API following this specification.

### Tags

- If the bridge sees one of our predefined special purpose tags, it should use the value of the tag to set the
  associated value, but the tag it self should not be stored. Example: The tag `user.id` should not be stored as a tag,
  but instead be used to populate `context.user.id` on the active transaction
- If no `type` tag is provided, the current span/transaction should use whatever their default type normally is

### Logs

- If a "log" is set on a span with an `event` field containing the value `error`, the bridge should do one of the
  following:
    - If the log contains an `error.object` field, expect that to be a normal error object and log that however the
      agent normally logs errors
    - Alternatively, if the log contains a `message` field, log that however the agent normally logs plain text messages

### Formats

- Tracers should support the text format. The value should be the same format as the http header value
- Tracers should _not_ support the binary format. Bridges should implement it as a no-op and optionally log a warning
  the first time the user tries to use the binary format

### Parent/Child relationships

- Tracers should only support a single "child-of" relationship
    - If a span is given a list of more than one parent relationship, use the first that is of type "child-of"
    - If the provided list of parent relationships doesn't contain a "child-of", the span should be a root-span
    - Optionally log a warning the first time an unsupported parent type is seen or if more than one parent is provided
