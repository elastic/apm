
## Terminology

**Vanilla OpenTelemetry Distribution**: this is the "upstream" OpenTelemetry distribution that is maintained by the OpenTelemetry community.
Implementation differs per platform, but it usually consists of an API/SDK and can also provide automatic instrumentation.

**Elastic OpenTelemetry Distribution**: this is an OpenTelemetry distribution provided by Elastic that is derived from the 
_Vanilla OpenTelemetry Distribution_.

## General guidelines

These statements are guiding principles of the Elastic OpenTelemetry distributions, they should be considered more as advice than strict rules.

Elastic OpenTelemetry distribution SHOULD ideally:
- behave as drop-in replacements of their upstream counterparts
- provide a simple setup and favor onboarding experience (aka "things should work by default").
- avoid capturing potentially confusing data (see [system metrics](#system-metrics) example below).

## Configuration

Elastic OpenTelemetry distributions MAY override the default configuration.
When doing so, user-configuration should remain consistent with vanilla distribution:
- explicit user configuration SHOULD remain effective
- overriden default configuration MUST have the ability to be restored to upstream default

Elastic specific configuration items MUST be prefixed with `ELASTIC_OTEL_`.
For example, the [inferred spans](#inferred-spans) feature is configured with `ELASTIC_OTEL_INFERRED_SPANS_*`.

Elastic and platform specific configuration items must be prefixed with `ELASTIC_OTEL_${platform}_` to be consistent with
the upstream `OTEL_${platform}_` prefix.

For simplicity the configuration in this specification will use the "environment variable" syntax, some platforms like Java
might also support other ways to configure.

## Features

### Inferred spans

Supported platforms: [Java](https://github.com/elastic/elastic-otel-java/tree/main/inferred-spans)

Configuration namespace: `ELASTIC_OTEL_INFERRED_SPANS_*`

### System metrics

These metrics are usually captured using the collector running locally but in case where no collector is present, or a centralized
collector is used then the user might opt in to also collect those.

These metrics are not captured by default in order to prevent duplicated metrics when they are also captured by a collector.

TODO : add link to supported platforms and respective implementations
TODO : add the configuration option name to enable those

### Cloud resource attributes

Supported platforms: Java

The cloud resource attributes ([semconv](https://opentelemetry.io/docs/specs/semconv/resource/cloud/)) provide equivalent 
attributes to the [cloud provider metadata](metadata.md#cloud-provider-metadata), which are usually provided
through a metadata HTTP(s) endpoint accessible from the application.

Elastic OpenTelemetry distributions SHOULD capture those by default for a better onboarding experience.
Users MUST be able to disable this default to minimize application startup overhead or if those attributes are provided through the collector.

Elastic distribution MUST extend the `OTEL_RESOURCE_PROVIDERS_${provider}_ENABLED` option to support the `false` value 
to allow disabling providers.
