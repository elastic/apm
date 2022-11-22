# Log streaming

### `log_streaming` configuration

**Warning**: experimental feature, may be subject to change until GA. Also, only a small subset of agents will provide it before GA.

Controls the ability to send logs directly from the agent to APM server.

|                |                 |
|----------------|-----------------|
| Valid options  | `true`, `false` |
| Default        | `false`         |
| Dynamic        | `true`          |
| Central config | `true`          |

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

### Agent log

When `log_streaming` option is enabled, the agent should also send its own logs to APM server.

For the `event.dataset` field, the `${service.name}.apm-agent` value should be used to allow keeping application logs
and agent logs separate if needed.

Unlike the application logs written with ecs-logging, the `service.name` value for agent logs will always be the one
set at agent level.
