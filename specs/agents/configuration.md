## Agent Configuration

Even though the agents should _just work_ with as little configuration and setup as possible we provide a wealth of ways to configure them to users' needs.

Generally we try to make these the same for every agent. Some agents might differ in nature like the JavaScript RUM agent but mostly these should fit. Still, languages are different so some of them might not make sense for your particular agent. That's ok!

Here's a list of the config options across all agents, their types, default values etc. Please align with these whenever possible:

- [APM Backend Agent Config Comparison](https://docs.google.com/spreadsheets/d/1JJjZotapacA3FkHc2sv_0wiChILi3uKnkwLTjtBmxwU/edit)

They are provided as environment variables but depending on the language there might be several feasible ways to let the user tweak them. For example besides the environment variable `ELASTIC_APM_SERVER_URL`, the Node.js Agent might also allow the user to configure the server URL via a config option named `serverUrl`, while the Python Agent might also allow the user to configure it via a config option named `server_url`.

### Configuration Source Precedence

Configuration can be provided via a number of sources. Values from central
configuration MUST have the highest precedence, and default values MUST have
the lowest precedence. Otherwise, agents MAY adopt the following config
source precedence. Sources higher on this list will override values provided
by sources lower on this list:

 - Central configuration
 - Environment variables
 - Inline configuration in code
 - Config files
 - Default value

### Invalid Configuration Values

If an invalid value for a configuration option is provided (for example:
`breakdown_metrics="yes"` or `apiRequestTime="1h"`) then the agent MUST ignore
the value (falling back to a config source with lower precedence) and SHOULD
emit a log warning about the ignored value.

### Configuration Value Types

The following list enumerates the available configuration types across the agents:

- `String`
- `Integer`
- `Float`
- `Boolean`: Encoded as a lower-case boolean string: `"false"`, `"true"`.
- `List`: Encoded as a comma-separated string (whitespace surrounding items should be stripped): `"foo,bar,baz"`.
- `Mapping`: Encoded as a string, with `"key=value"` pairs separated by commas (whitespace surrounding items should be stripped): `"foo=bar,baz=foo"`.
- `Duration`: Case-sensitive string with duration encoded using unit suffixes (`ms` for millisecond, `s` for second, `m` for minute). Validating regex: `^(-)?(\d+)(ms|s|m)$`.
- `GranularDuration`: Case-sensitive string with duration encoded using unit suffixes which supports down to a microsecond duration (`us`). Validating regex: `^(-)?(\d+)(us|ms|s|m)$`.
- `Size`: Case-insensitive string with a positive size encoded using unit suffixes (`b` for bytes, `kb` for kilobytes, `mb` for megabytes, `gb` for gigabytes, with a 1024 multiplier between each unit). Validating regex: `^(\d+)(b|kb|mb|gb)$`.


### Configuration snapshotting

To ensure consistent behavior within one transaction,
certain settings SHOULD be read at the beginning of the transaction.
The snapshot of these configuration values applies for the lifetime of the
transaction.

Snapshotted configuration options:

 * `transaction_max_spans`
 * `span_compression_enabled`
 * `span_compression_exact_match_max_duration`
 * `span_compression_same_kind_max_duration`
 * `exit_span_min_duration`
 

#### Duration/Size Config Legacy Considerations

For duration/size-formatted config options, some agents allow users to omit the unit
suffix for backwards compatibility reasons. Going forward, all
duration/size-formatted config options should require the unit suffix, falling back
to the default value if an invalid value is provided.  Existing
duration/size-formatted config options should be changed to require the unit suffix
at the next major version.

### APM Agent Configuration via Kibana

Also known as "central configuration". Agents can query the APM Server for configuration updates; the server proxies and caches requests to Kibana.

Agents should poll the APM Server for config periodically by sending an HTTP request to the `/config/v1/agents` endpoint. Agents must specify their service name, and optionally environment. The server will use these to filter the configuration down to the relevant service and environment. There are two methods for sending these parameters:

1. Using the `GET` method, pass them as query parameters: `http://localhost:8200/config/v1/agents?service.name=opbeans&service.environment=production`
2. Using the `POST` method, encode the parameters as a JSON object in the body, e.g. `{"service": {"name": "opbeans", "environment": "production"}}`

The server will respond with a JSON object, where each key maps a config attribute to a string value. The string value should be interpreted the same as if it were passed in via an environment variable. Upon receiving these config changes, the agent will update its configuration dynamically, overriding any config previously specified. That is, config via Kibana takes highest precedence.

To minimise the amount of work required by users, agents should aim to enable this feature by default. This excludes RUM, where there is a performance penalty.

#### Interaction with local config

When an instrumented application starts, the agent should first load locally-defined configuration via environment variables, config files, etc. Once this has completed, the agent will begin asynchronously polling the server for configuration. Once available, this configuration will override the locally-defined configuration. This means that there will be a short time window at application startup in which locally-defined configuration will apply.

If a user defines and then later deletes configuration via Kibana, the agent should ideally fall back to the locally-defined configuration. As an example of how to achieve this: the Java agent defines a hierarchy of configuration sources, with configuration via Kibana having the highest precedence. When configuration is not available at one level, the agent obtains it via the next highest level, and so on.

#### Caching

As mentioned above, the server will cache config for each unique `service.name`, `service.environment` pair. The server will respond to config requests with two related response headers: [Etag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) and [Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control).

Agents should keep a record of the `Etag` value returned by the most recent successful config request, and then present it to future requests via the [If-None-Match](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-None-Match) header. If the config has not changed, the server will respond with 304 (Not Modified).

The `Cache-Control` header should contain a `max-age` directive, specifying the amount of time (in seconds) the response should be considered "fresh". Agents should use this to decide how long to wait before requesting config again. The server will respond with a `Cache-Control` header even if the request fails.

#### Dealing with errors

Agents must deal with various error scenarios, including:

 - 7.3 servers where the Kibana connection is not enabled (server responds with 403)
 - 7.3 servers where the Kibana connection is enabled, but unavailable (server responds with 503)
 - pre-7.3 servers that don't support the config endpoint (server responds with 404)
 - any other error (server responds with 5xx)

If the server responds with any 5xx, agents should log at error level. If the server responds with 4xx, agents are not required to log the response, but may choose to log it at debug level; either the central config feature is not available, or is not enabled. In either case, there is no expectation that the agent should take any action, so logging is not necessary.

In any case, a 7.3+ server _should_ respond with a Cache-Control header, as described in the section above, and agents should retry after the specified interval. For older servers, or for whatever reason a 7.3+ server does not respond with that header (or it is invalid), agents should retry after 5 minutes. We include this behaviour for older servers so that the agent will start polling after server upgrade without restarting the application.

If the agent does not recognise a config attribute, or does not support dynamically updating it, then it should log a warning such as:

```
Central config failure. Unsupported config names: unknown_option, disable_metrics, capture_headers
```

Note that in the initial implementation of this feature, not all config attributes will be supported by the APM UI or APM Server. Agents may choose to support only the attributes supported by the UI/server, or they may choose to accept additional attributes. The latter will enable them to work without change once additional config attributes are supported by the UI/server.

If the agent receives a known but invalid config attribute, it should log a warning such as:

```
Central config failure. Invalid value for transactionSampleRate: 1.2 (out of range [0,1.0])
```

Failure to process one config attribute should not affect processing of others.

To ensure graceful recovery if the APM Server is offline or there is a network partition, agents should only retry at a maximum every 5 seconds, regardless of Cache-Control headers being less than that value. If the Cache-Control header is zero (or less than zero), it should be treated as missing (i.e. use default retry time).

#### Feature flag

Agents should implement a [configuration option](https://docs.google.com/spreadsheets/d/1JJjZotapacA3FkHc2sv_0wiChILi3uKnkwLTjtBmxwU), (`CENTRAL_CONFIG`) which lets users disable the central configuration polling.

### Zero-configuration support

To decrease onboarding friction,
APM agents MUST not require any configuration to send data to a local APM Server.
After onboarding, users can customize settings for which the defaults aren't appropriate.

By default, agents MUST send data to the APM Server at `http://localhost:8200/`.
If possible, agents SHOULD detect sensible defaults for `service.name` and `service.version`.
In any case agents MUST include `service.name` - if discovering it is not possible then the default value: `unknown-${service.agent.name}-service` MUST be used.
This naming pattern allows the UI to display inline help on how to manually configure the name.

### Adding a new configuration option

#### Configuration option spec template

When adding a new configuration option to the spec, please use the following template:

```markdown
### <option_name_in_central_config_notation> configuration

The description of the option.
Try to phrase it in a way that lets agents easily copy/paste the description into their configuration documentation page.
This should also match the description in the [central configuration](https://github.com/elastic/kibana/blob/main/x-pack/plugins/apm/common/agent_configuration/setting_definitions/general_settings.ts) in the APM UI.

|                |                                           |
|----------------|-------------------------------------------|
| Type           | See the Configuration Value Types section |
| Default        | `<default value>`                         |
| Central config | `<true/false>`                            |

Additional description of the option that should not be part of the documentation.
For example, whether agents SHOULD or MUST implement the option.

```

#### Adding to central configuration

One of the things to determine when proposing to add a new configuration option is whether it should be added to central configuration.
In general, we should try to make the majority of options available in central configuration.
However, sometimes it might not be feasible if agents need to read the value at startup and changing the value at runtime is very difficult to achieve.

When adding a centrally configurable option,
the spec owner is expected to create a pull request in the Kibana repository to add the option to central configuration.

To make sure the tests are passing and to update some generated files, you need a local clone of Kibana and execute the build.
Follow [Kibana's contribution guide](https://github.com/elastic/kibana/blob/main/CONTRIBUTING.md) to get a local environment running.

Add the configuration option(s) using this [example PR](https://github.com/elastic/kibana/pull/143668) as a reference.
By the time you're adding the configuration option, chances are that no agent has implemented the option, yet.
Therefore, set `includeAgents: []` in the option declaration.
When an agent implements the option, they just need to add the agent name to this section, without having to test the changes.
Please manually add a checkbox to all the implementation issues to make sure agents don't forget that step.

Before creating a PR, execute the [jest tests and update the generated snapshot files](https://github.com/elastic/kibana/blob/main/x-pack/plugins/apm/dev_docs/testing.md#unit-tests-jest).
For testing purposes, comment out the `includeAgents` declaration and remember add it back in after testing.
This ensures that you can just select `all` services and `all` environments in the central configuration UI.  
To test the changes, run Elasticsearch and Kibana as described in the contribution guide.
Just try out whether the option is rendered as expected and triple-check that the option name matches the one in the spec.

When creating the PR, add the labels `release_note:enhancement`, `Team:APM`, and `v<next minor stack release>`.

If everything works smoothly, request a review from the [apm-ui](https://github.com/orgs/elastic/teams/apm-ui) team.
If you need help, drop a message in the #apm-dev channel so that agent devs that did this before or UI devs can chime in.
