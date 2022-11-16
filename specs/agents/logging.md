# Agent logging

## `log_level` configuration

Sets the logging level for the agent.

This option is case-insensitive.

|                |   |
|----------------|---|
| Valid options  | `trace`, `debug`, `info`, `warning`, `error`, `critical`, `off` |
| Default        | `info` (soft default) |
| Dynamic        | `true` |
| Central config | `true` |

Note that this default is not enforced among all agents.
If an agent development team thinks that a different default should be used
(such as `warning`), that is acceptable.

## Mapping to native log levels

Not all logging frameworks used by the different agents can natively work with these levels.
Thus, agents will need to translate them, using their best judgment for the mapping.

Some examples:
If the logging framework used by an agent doesn't have `trace`,
it would map it to the same level as `debug`.
If the underlying logging framework doesn't support `critical`,
agents can treat that as a synonym for `error` or `fatal`.

The `off` level is a switch to completely turn off logging.

## Backwards compatibility

Most agents have already implemented `log_level`,
accepting a different set of levels.
Those agents should still accept their "native" log levels to preserve backwards compatibility.
However, in central config,
there will only be a dropdown with the levels that are consistent across agents.
Also, the documentation should not mention the old log levels going forward.

## Logging Preamble

All log messages described in this section MUST be printed using the `info` logging level
unless a different level is explicitly mentioned.

The agent logging preamble consists of 3 blocks:

* **Agent**: This block is mandatory and contains basic version and build date information.
* **Environment**: This block is optional but for supportability reasons it should be provided.
* **Configuration**: This block is mandatory and contains a minimum set of relevant configuration values.

**Note** that this specification does not prescribe a specific format to be used for creating 
the log messages. It is up to the implementing agent to chose a format (e.g. ecs-logging format).

### Agent

On startup, all APM agents MUST log basic information regarding their technology (language, runtime),
and version information.
This log message MUST provide sufficient data to uniquely identify the agent build that generated the
log message. Hence, if e.g. the version information is not sufficient, agents
MUST include further information (e.g. build timestamp, git hash) that uniquely identifies an agent build.

This SHOULD be the very first log message that is created by an agent.

Example:

```text
Elastic APM .NET Agent, version: 1.19.1-preview, build date: 2022-10-27 10:55:42 UTC
```

Agents SHOULD also detect when they are running in a non-final version (e.g. a debug
or pre-release build) and report that fact using the `warning` logging level.

Example:

```text
This is a pre-release version and not intended for use in production environments!
```

### Environment

Additionally, agents SHOULD report information about their environment (e.g. host, process, runtime).

| Item | Description | Example |
| - | - | - |
| Process ID | The Process ID in decimal format. | `83606` |
| Process Name | The executable image name or the full path to it.  | `w3wp.exe`, `/usr/local/share/dotnet/dotnet` |
| Command Line | The full command line used to launch this process as available to the runtime. [1]  | `/Users/acme/some_app/bin/Debug/net7.0/some_app.dll foo=bar` |
| Operating System | OS name and version in a human-readable format. | `macOS Version 12.6.1 (build 21G217)` |
| CPU architecture | See table below. | `arm64` |
| Host | The (optionally fully-qualified) host name. | `MacBook-Pro.localdomain` |
| Time zone | The local time zone in UTC-offset notation. | `UTC+0200` |
| Runtime | Name and version of the executing runtime. | `.NET Framework 4.8.4250.0`|

[1]: Due to privacy concerns in the past (see e.g. [here](https://github.com/elastic/apm-agent-nodejs/issues/1916)),
agents may decided to not log this information.

**CPU Architecture:**

This table provides an exemplary list of well-known values for reporting the CPU architecture.
An agent can decide to use different values that might be readily available to their language/runtime
ecosystem (e.g. Node.js' `os.arch()`).

| Value | Description |
| - | - |
| `amd64` | AMD64 |
| `arm32` |ARM32 |
| `arm64` |ARM64 |
| `ia64` | Itanium |
| `ppc32` | 32-bit PowerPC |
| `ppc64` | 64-bit PowerPC |
| `s390x` | IBM z/Architecture |
| `x86` | 32-bit x86 |

### Configuration

The start of the configuration block MUST be denoted as such (e.g. `Agent Configuration:`).

If configuration files are used in the configuration process, their fully-qualified paths
SHOULD be logged.

Configuration item names SHOULD be provided in normalized (lower-case, snake_case) notation.
Configuration value strings MUST be printed in quotes (so accidental leading or trailing whitespace can be spotted).

Agents SHOULD log all configuration items that do not have default values.
At the very minimum, agents MUST provide information about following essential configuration items.
Items denoted as *"Log always"* MUST be logged in any case (i.e. having a default value or a custom one).

| Item | Needs masking | Log Always | Example |
| - | - | - | - |
| `server_url` | no | yes | `http://localhost:8200` [2] |
| `service_name` | no | yes | `foo` |
| `service_version` | no | yes | `42` |
| `log_level` | no | yes | `warning` |
| `secret_token` | yes | no | `[REDACTED]` |
| `api_key` | yes | no | `[REDACTED]` |

[2]: Agents MAY decide to mask potential sensitive data (e.g. basic authentication information)
that could be part of this URL.

For each configuration option its **source** SHOULD be reported. These sources can be:

* `default`
* `environment`: Environment variable
* `file`: Configuration file
* `central`: Central Configuration
  * **Note:** Agents MAY print their configuration block again on changes in the central configuration.

Example:

```text
Agent Configuration:
- configuration files used:
  - '/path/to/some/config.json'
  - '/path/to/some/other/config.xml'
- server_url: 'http://localhost:8200' (default)
- secret_token: [REDACTED] (environment)
- api_key: [REDACTED] (default)
- service_name: `unknown-dotnet-service` (default)
- log_level: info (file)
- disable_metrics: '*' (file)
```
