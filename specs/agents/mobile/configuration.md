## Mobile Configuration

This document describes the configurable parameters used in mobile agents. The ones supported
by [central configuration](../configuration.md) can be set through Kibana's APM Settings.

### `recording` configuration

A boolean specifying if the agent should be recording or not. When recording, the agent instruments incoming HTTP
requests, tracks errors and collects and sends metrics. When not recording, the agent works as a noop, not collecting
data and not communicating with the APM sever, except for polling the central configuration endpoint. As this is a
reversible switch, agent threads are not being killed when inactivated, but they will be mostly idle in this state, so
the overhead should be negligible.

You can use this setting to dynamically disable Elastic APM at runtime.

|                |           |
|----------------|-----------|
| Type           | `Boolean` |
| Default        | `true`    |
| Central config | `true`    |
