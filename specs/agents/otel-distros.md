# Building OpenTelemetry Distros

> A distribution, not to be confused with a fork, is customized version of an OpenTelemetry component. A distribution is a wrapper around an 
> upstream OpenTelemetry repository with some customizations.
>
> -- <cite>https://opentelemetry.io/docs/concepts/distributions/</cite>

## Introduction

Elastic distros are designed to support ease of use and enhanced features. We will leverage the underlying OpenTelemetry libraries for most functionality. Our thin wrapper over these libraries SHOULD support a familiar API. 

Distributions should provide a simple, opinionated default configuration, listening to common sources (HTTP, SQL, etc.) and exporting data to an Elastic APM backend using OTLP. Additional features, not available in the OpenTelemetry library, can be introduced via appropriate extension points, with a view to contributing these upstream when possible.

Distributions SHOULD follow this specification for behaviours and implemented functionality.

## User Agent Headers

Per the [OpenTelemetry Specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md#user-agent), OpenTelemetry SDKs are expected to send a `User-Agent` header when exporting data to a backend. At a minimum, this header SHOULD identify the exporter, the language of its implementation, and the version of the exporter.

Elastic distributions SHOULD configure a customized `User-Agent` header when possible. This allows data exported from a vanilla SDK and an Elastic distribution to be easily distinguished.

To conform with [RFC7231](https://datatracker.ietf.org/doc/html/rfc7231#section-5.5.3), the exiting SDK `User-Agent` should be preceded by a product identifier and version for the distribution.

```
Elastic-Otel-Distro-<language>\<version> <original-sdk-user-agent>
```

For example, in the .NET distribution, the `User-Agent` header would be configured as follows:

```
Elastic-Otel-Distro-Dotnet\1.0.0 OTel-OTLP-Exporter-Dotnet/1.6.0
```

## Telemetry SDK (Agent Metadata)

Per the [semantic conventions](https://opentelemetry.io/docs/specs/semconv/resource/#telemetry-sdk), SDKs are expected to include the following attributes on spans. These are used to identify the SDK where the data was captured.

- `telemetry.sdk.name`
- `telemetry.sdk.version`

Our intake data models read these attributes and use them to populate the `agent.Name` and `agent.Version` fields.

The semantic conventions also [define two experimental attributes](https://opentelemetry.io/docs/specs/semconv/resource/#telemetry-sdk-experimental).

- `telemetry.distro.name`
- `telemetry.distro.version`

Distributions SHOULD set these attributes with values that uniquely describe the Elastic distribution wrapping the SDK. 

For the distribution name, the format should be as follows:

```
elastic-<language>
```

As an example, the .NET `telemetry.distro.name` attribute value should be `elastic-dotnet`.

The version should reflect the assembly version of the dsitribution.

**_NOTE: The intake APM data model must be updated to map these new experimental attributes to the agent fields. TODO - We should decide whether `telemetry.sdk.name` should also be used to suffix the distribution name._**