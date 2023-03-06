## Mobile Configuration

This document describes the [central configuration](../configuration.md) parameters used in mobile agents. These values
can be set through Kibana's APM Settings.

### `enable_automatic_instrumentation` configuration

Specifies if the agent should automatically trace its supported technologies. If set to `false`, only manually collected
APM data will be sent over to the APM server.

|                |           |
|----------------|-----------|
| Type           | `Boolean` |
| Default        | `true`    |
| Central config | `true`    |
