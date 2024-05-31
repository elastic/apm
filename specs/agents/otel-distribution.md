
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
For example, the [universal profiling integration](#universal-profiling-integration) can be enabled with `ELASTIC_OTEL_UNIVERSAL_PROFILING_INTEGRATION_ENABLED`.

Elastic and platform specific configuration items must be prefixed with `ELASTIC_OTEL_${platform}_` to be consistent with
the upstream `OTEL_${platform}_` prefix.

When introducing new features, the decision between starting with platform-specific or general namespace is made on a feature by feature case:
- feature can be aligned cross-platform even if implemented only in only one: use `ELASTIC_OTEL_` prefix, for example [System metrics](#system-metrics).
- feature that we know will be platform-specific: use `ELASTIC_OTEL_${platform}_` prefix.

For simplicity the configuration in this specification will use the "environment variable" syntax, some platforms like Java
might also support other ways to configure.

## Identification

### User Agent headers

Per the [OpenTelemetry Specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md#user-agent), OpenTelemetry SDKs are expected to send a `User-Agent` header when exporting data to a backend. At a minimum, this header SHOULD identify the exporter, the language of its implementation, and the version of the exporter.

Elastic distributions SHOULD configure a customized `User-Agent` header when possible[^1].
This allows data exported from a vanilla SDK and an Elastic distribution to be easily distinguished.

[^1]: Some OpenTelemetry SDKs (e.g. .NET) do not provide a mechanism to modify the `User-Agent` header. In this case, we accept their default._

To conform with [RFC7231](https://datatracker.ietf.org/doc/html/rfc7231#section-5.5.3), the existing SDK `User-Agent` should be preceded by a product identifier and version for the Elastic distribution.

```
<repo-name>/<version> <existing-otel-sdk-user-agent>
```

For example, in the .NET distribution, the `User-Agent` header would be configured as follows:

```
elastic-otel-dotnet/1.0.0 OTel-OTLP-Exporter-Dotnet/1.6.0
```

### Telemetry resource attributes

Per the [semantic conventions](https://opentelemetry.io/docs/specs/semconv/resource/#telemetry-sdk), SDKs are expected to include the following resource attributes on captured signals. These are used to identify the SDK where the data was captured and should not be modified.

- `telemetry.sdk.name`
- `telemetry.sdk.version`
- `telemetry.sdk.language`

In the above attributes, the name and version should be the OTel SDK name and version.
The language should be the primary language that the SDK is intended for.
It is expected that the OpenTelemetry SDK sets these values.
Our distros should set them, only if the SDK code does not do so automatically.

Intake currently reads these attributes and uses them to populate the `agent.Name` and `agent.Version` fields.

The semantic conventions also [define two experimental attributes](https://opentelemetry.io/docs/specs/semconv/resource/#telemetry-sdk-experimental) to identify the distribution:

- `telemetry.distro.name`: must be set to `elatic`
- `telemetry.distro.version`: must reflect the distribution version

Distributions SHOULD set these attributes with appropriate values.

## Features

### Inferred spans

Supported platforms: [Java](https://github.com/elastic/elastic-otel-java/tree/main/inferred-spans)

Configuration to enable: `ELASTIC_OTEL_INFERRED_SPANS_ENABLED`

Note: While the implementation is Java-only for now, it should probably have been using `ELASTIC_OTEL_JAVA_INFERRED_SPANS_ENABLED`
instead, but we plan to fix this inconsistency once it has been contributed upstream.

### System metrics

These metrics are usually captured using the collector running locally but in case where no collector is present, or a centralized
collector is used then the user might opt in to also collect those.

These metrics are not captured by default in order to prevent duplicated metrics when they are also captured by a collector.

TODO : add link to supported platforms and respective implementations
TODO : add the configuration option name to enable those

### Cloud resource attributes

Supported platforms: Java

The cloud resource attributes ([semconv](https://opentelemetry.io/docs/specs/semconv/resource/cloud/)) is a subset of
the [resource attributes](https://opentelemetry.io/docs/specs/semconv/resource/) providing equivalent attributes to the
[cloud provider metadata](metadata.md#cloud-provider-metadata).
Those attributes are usually provided through a metadata HTTP(s) endpoint accessible from the application.

Elastic OpenTelemetry distributions SHOULD capture those by default for a better onboarding experience.
Users MUST be able to disable this default to minimize application startup overhead or if those attributes are provided through the collector.

Elastic distribution MUST allow to opt out of this behavior through explicit configuration.
Implementation is currently platform specific:
- Java: `OTEL_RESOURCE_PROVIDERS_${provider}_ENABLED=false`
- NodeJS: `OTEL_NODE_RESOURCE_DETECTORS` ([doc](https://github.com/open-telemetry/opentelemetry-js-contrib/tree/main/metapackages/auto-instrumentations-node/#usage-auto-instrumentation))

### Universal profiling integration

Supported platforms: [Java](https://github.com/elastic/elastic-otel-java/tree/main/universal-profiling-integration)

For the configuration options see [this section](universal-profiling-integration.md#configuration-options).
