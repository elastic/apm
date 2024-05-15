
## Terminology

**Vanilla OpenTelemetry Distribution**: this is the "upstream" OpenTelemetry distribution that is maintained by the OpenTelemetry community.
Implementation differs per platform, but it usually consists of an API/SDK and can also provide automatic instrumentation.

**Elastic OpenTelemetry Distribution**: this is an OpenTelemetry distribution provided by Elastic that is derived from the 
_Vanilla OpenTelemetry Distribution_.

## General guidelines

Those statements are guiding principles of the Elastic OpenTelemetry distributions, they should be considered more as advice than strict rules.

Elastic OpenTelemetry distribution SHOULD ideally:
- behave as drop-in replacements of their upstream counterparts
- provide a simple setup and favor onboarding experience (aka "things should work by default").
- avoid capturing potentially confusing data (see #system-metrics example below).

## Configuration

Elastic OpenTelemetry distributions MAY override the default configuration.
When doing so, user-configuration should remain consistent with vanilla distribution:
- explicit user configuration SHOULD remain effective
- overriden default configuration SHOULD be revertable through configuration

Elastic specific configuration items MUST be prefixed with `ELASTIC_OTEL` or `elastic.otel`.
For example, the #inferred-spans feature is configured with `ELASTIC_OTEL_INFERRED_SPANS_*`

## Features

### Inferred spans

TODO: add link to supported platforms and respective implementations

### System metrics

Those metrics are usually captured using the collector running locally but in case where no collector is present, or a centralized
collector is used then the user might opt-in to also collect those.

Those metrics are not captured by default to prevent duplicated metrics when they are also captured by a collector.

TODO : add link to supported platforms and respective implementations
TODO : add the configuration option name to enable those
