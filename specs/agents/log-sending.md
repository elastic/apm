# Log sending

### `log_sending` configuration

**Warning**: experimental feature, may be subject to change until GA. Also, only a small subset of agents will provide it before GA.

Controls the ability to send logs directly from the agent to APM server.

|                |                 |
|----------------|-----------------|
| Valid options  | `true`, `false` |
| Default        | `false`         |
| Dynamic        | `true`          |
| Central config | `true`          |

When set to `true`, the agent will duplicate log events and send them to apm-server.
Original log events are unaltered and written to their usual destinations (file, stdout, ...).

The APM server only supports log events as of version 8.6+, thus trying to use this with an older version should
issue a warning/error in the agent logs.

### Log event format

On the agent side, there are two ways to get an ECS-formatted log message from a log event:
- The application already uses [ecs-logging](https://github.com/elastic/ecs-logging)
- The agent embeds a copy of [ecs-logging](https://github.com/elastic/ecs-logging), which might also be used for [log reformatting](./log-reformatting.md).

In both cases, the output of [ecs-logging](https://github.com/elastic/ecs-logging) can be reused as follows:

```
{"log":<ecs-formatted-log-event>}\n`
```

The ECS logging event `<ecs-formatted-log-event>` must not include an `EOL` character in order to preserve the ND-JSON
format where each event is written to a single line.

### Log event fields

The ECS logging fields are the same as the ones defined in log reformatting:
- [required fields](./log-reformatting.md#required-fields)
- [recommended fields](./log-reformatting.md#recommended-fields)

However, the values of `service.name` and `service.version` can be omitted as they are redundant to the values that are
already sent in the [ND-JSON metadata](metadata.md). In the case where the formatted ECS log event already contains
them it might be more efficient to send the event as-is, rather than rewriting the event.

### Agent log

When `log_sending` option is enabled, agents may also send their own logs to APM server.

Agents usually have internal debug/trace logging statements that allow to diagnose communication issues and serialized data
sent to APM server. Special care must be taken to ensure that sending APM agent logs do not trigger an exponential loop
of log events or excessively large log event.
For APM agent logs, ignoring those log statements is an acceptable compromise, if there is any communication or 
serialization issue with APM server it will already be logged for application traces, logs and metrics sent by the agent.

When the agent starts, agent log events might require some limited buffering until the agent initialization is complete.
This allows to capture the early log messages when the agent initializes which often provide details about the agent
setup and configuration which are required for support.

For the `event.dataset` field, the `${service.name}.apm-agent` value should be used to allow keeping application logs
and agent logs separate if needed.
