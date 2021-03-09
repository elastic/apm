## Agent logging

### `log_level` configuration

Sets the logging level for the agent.

This option is case-insensitive.

|----------------|---|
| Valid options  | `trace`, `debug`, `info`, `warning`, `error`, `critical`, `off` |
| Default        | `info` (soft default) |
| Dynamic        | `true` |
| Central config | `true` |

Note that this default is not enforced among all agents.
If an agent development team thinks that a different default should be used
(such as `warning`), that is acceptable.

### Mapping to native log levels


Not all logging frameworks used by the different agents can natively work with these levels.
Thus, agents will need to translate them, using their best judgment for the mapping.

Some examples:
If the logging framework used by an agent doesn't have `trace`,
it would map it to the same level as `debug`.
If the underlying logging framework doesn't support `critical`,
agents can treat that as a synonym for `error` or `fatal`.

The `off` level is a switch to completely turn off logging.

### Backwards compatibility

Most agents have already implemented `log_level`,
accepting a different set of levels.
Those agents should still accept their "native" log levels to preserve backwards compatibility.
However, in central config,
there will only be a dropdown with the levels that are consistent across agents.
Also, the documentation should not mention the old log levels going forward.

### `log_ecs_formatting` configuration

Configures the agent to automatically format logs as ECS-compatible JSON
(if possible).

|----------------|---|
| Valid options  | `on`, `off` |
| Default        | `off`  |
| Dynamic        | `false` |
| Central config | `false` |

Not all agents will be able to automatically format logs in this way. Those
agents should not implement this configuration option.

For some agents, additional options makes sense. For example, the Java agent
also accepts the values `shade` and `replace`.

When this option is set to `on`, the agent should format all logs from the
app as ECS-compatible json, as shown in the
[spec](https://github.com/elastic/ecs-logging/blob/master/spec/spec.json).

#### Required fields

The following fields are required:

* `@timestamp`
* `log.level`
* `message`
* `ecs.version`

#### Recommended fields

The following fields are important for a good user experience in Kibana,
but will not cause errors if they are omitted:

##### `service.name`

Agents should always populate
[`service.name`](https://github.com/elastic/ecs-logging/blob/18cde109acb284c97988f9df9defb685b798db9a/spec/spec.json#L66-L74)
even if there is not an active transaction.

##### `event.dataset`

The
[`event.dataset`](https://github.com/elastic/ecs-logging/blob/18cde109acb284c97988f9df9defb685b798db9a/spec/spec.json#L75-L91)
field is used in some ML jobs in Elasticsearch to surface anomalies within
datasets. This field should be a step more granular than `service.name` where
possible. However, the cardinality of this field should be limited, so
per-class or per-file logger names are not appropriate for this field.

A good example is in the Java agent, where `event.dataset` is set to the
log appender name.

If an agent doesn't have reasonable options for this field, it should be set
to `${service.name}.log`.
