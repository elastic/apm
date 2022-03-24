TODO: this content will be appended to "span-links.md" when that file is added in https://github.com/elastic/apm/pull/600

### API

Agents MAY provide a public API to add span links at span/transaction creation.
A use-case for user's manually adding span links is for [batch message processing](tracing-instrumentation-messaging.md#batch-message-processing)
that the APM agent does not or cannot instrument. (For some agents it would be
a burden to internally support span links and *not* expose the API publicly.)

TODO: For the .NET APM agent is there much value in providing a public API to add span links? Perhaps usage of the Activity API and the OTel Bridge dominates?

If provided, the API SHOULD be written such that user code is not broken if/when
support for span link *attributes* is added in the future.

If provided, the API and semantics SHOULD be compatible with the
[OpenTelemetry specification on specifying span links](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#specifying-links). A compatible API will facilitate
[OpenTelemetry bridge](trace-api-otel.md) support. OpenTelemetry requirements:

- The public API MUST NOT allow adding span links *after* span creation.
- Links SHOULD preserve the order in which they are set.

TODO: Does the [suggested](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#specifying-links) "AddLink" method name for a SpanBuilder-type interface (as in the OTel Java API) make sense for any of the Elastic APM agent APIs? My understanding is the answer is "no" for Java, Node.js, Python, Go, .NET at least.
