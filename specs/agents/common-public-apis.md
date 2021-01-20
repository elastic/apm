## Common Public APIs

This document describes APM Agent Public APIs that are or should be common
between the separate language implementations; and that are not defined in
a separate document such as the [Tracing API](./tracing-api.md).

In the following APIs, the string "apm" is used to refer to the top-level
namespace or primary singleton API object provided by the APM agent:

- Node.js: the singleton [Agent instance](https://www.elastic.co/guide/en/apm/agent/nodejs/current/agent-api.html)
- Go: the [Tracer](https://www.elastic.co/guide/en/apm/agent/go/current/api.html#tracer-api) instance
- Java: the [`co.elastic.apm.api.ElasticApm` class](https://www.elastic.co/guide/en/apm/agent/java/current/public-api.html)
- .NET: the [`Elastic.Apm.Agent` class](https://www.elastic.co/guide/en/apm/agent/dotnet/current/public-api.html)
- Python: the [`elasticapm` package](https://www.elastic.co/guide/en/apm/agent/python/current/api.html)
- Ruby: the [`ElasticAPM` module](https://www.elastic.co/guide/en/apm/agent/ruby/current/api.html)
- RUM JS: the singleton [Agent instance](https://www.elastic.co/guide/en/apm/agent/js-base/current/agent-api.html)


### `apm.getServiceName() -> String`

Alternative spellings as makes sense for each Agent: `.get_service_name()`,
`.GetServiceName()`.

This API returns the service name, which may have been explicitly configured
or automatically discovered.

Use cases:

- [ecs-loggers](https://github.com/elastic/ecs-logging) may use this to fill in
  the "service.name" and "event.dataset" ECS logging fields.

