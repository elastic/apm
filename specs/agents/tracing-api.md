## Tracer APIs

All agents must provide a native API to enable developers to instrument their applications manually, in addition to any
automatic instrumentation.

Agents document their APIs in the elastic.co docs:

- [Node.js Agent](https://www.elastic.co/guide/en/apm/agent/nodejs/current/api.html)
- [Go Agent](https://www.elastic.co/guide/en/apm/agent/go/current/api.html)
- [Java Agent](https://www.elastic.co/guide/en/apm/agent/java/current/public-api.html)
- [.NET Agent](https://www.elastic.co/guide/en/apm/agent/dotnet/current/public-api.html)
- [Python Agent](https://www.elastic.co/guide/en/apm/agent/python/current/api.html)
- [Ruby Agent](https://www.elastic.co/guide/en/apm/agent/ruby/current/api.html)
- [RUM JS Agent](https://www.elastic.co/guide/en/apm/agent/js-base/current/api.html)

In addition, each agent may provide "bridge" implementations of vendor-neutral APIs:

- [OpenTracing API](tracing-api-ot.md).
- [OpenTelemetry API](tracing-api-otel.md).
