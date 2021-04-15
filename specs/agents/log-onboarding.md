# Log Onboarding

The Agents will be a critical part of log collection onboarding for their
application logs. This is primarily accomplished via the `log_ecs_formatting`
configuration option, described below.

In future iterations, the shipping of ECS logs will become more automated by auto-parsing ECS-JSON logs in Filebeat and [automatically shipping log files](https://github.com/elastic/apm/issues/374) that got reformatted via `log_ecs_formatting`.

## `log_ecs_formatting` configuration

Configures the agent to automatically format application logs as ECS-compatible JSON
(if possible).

The configuration option must be marked experimental for now to allow for breaking changes we may need to introduce.
Once the end-to-end process for seamless log onboarding with Elastic Agent works, we'll remove the experimental flag.

As the implementation of this configuration option will be specific for each supported log library,
the supported technologies documentation should list the supported frameworks (including supported version ranges)
and the agent version that introduced support for each logging library.

|                |   |
|----------------|---|
| Valid options  | `override`, `off` (case insensitive) |
| Default        | `off`   |
| Dynamic        | `false` |
| Central config | `false` |

Not all agents will be able to automatically format logs in this way. Those
agents should not implement this configuration option.

For some agents, additional options makes sense. For example, the Java agent
also accepts the values `shade` and `replace`, where ECS-reformatted logs are written to a dedicated `.ecs.json` 
file in addition to (`shade`) or instead of (`replace`) the original log stream.

When this option is set to `override`, the agent should format all logs from the
app as ECS-compatible json, as shown in the
[spec](https://github.com/elastic/ecs-logging/blob/master/spec/spec.json).

For all options other than `off`, the [log correlation](log-correlation.md) should be implicitly enabled.
### Required fields

The following fields are required:

* `@timestamp`
* `log.level`
* `message`
* `ecs.version`

### Recommended fields

The following fields are important for a good user experience in Kibana,
but will not cause errors if they are omitted:

#### `service.name`

Agents should always populate `service.name` even if there is not an active
transaction.

The `service.name` is used to be able to add a logs tab to the service view in
the UI. This lets users quickly get a stream of all logs for a particular
service.

#### `event.dataset`

The `event.dataset` field is used  to power the [log anomaly chart in the logs UI](https://www.elastic.co/guide/en/observability/current/inspect-log-anomalies.html#anomalies-chart).
The dataset can also be useful to filter for different log streams from the same pod, for example.
This field should be a step more granular than
`service.name` where possible. However, the cardinality of this field should be
limited, so per-class or per-file logger names are not appropriate for this
field.

A good example is in the Java agent, where `event.dataset` is set to
`${service.name}.${appender.name}`, where `appender.name` is the name of the
log appender.

If an agent doesn't have reasonable options for this field, it should be set
to `${service.name}.log`.

Some examples:
- opbeans.log
- opbeans.checkout
- opbeans.login
- opbeans.audit
## Testing

Due to differences in the possible Agent implementations of this feature, no
Gherkin spec is provided. Testing will primarily be accomplished via Opbeans.
Each Agent team should update their Opbeans app so that it only relies on this
configuration option to format ECS logs that will be picked up by Filebeat.
