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
version information, and build date in a format chosen by the respective agent.

This SHOULD be the very first log message that is created by an agent.

Example:

```text
Elastic APM .NET Agent, version: 1.19.1-preview, build date: 2022-10-27 10:55:42 UTC
```

Agents SHOULD also detect when they are running in a non-final version (e.g. a debug
or pre-release build) and report that fact using the `warning` logging level.

Example:

```text
This a pre-release version and not intended for use in production environments!
```

### Environment

Additionally, agents SHOULD report information about their environment (e.g. host, process, runtime).

| Item | Description | Example |
| - | - | - |
| Process ID | The Process ID in decimal format. | `83606` |
| Process Name | The executable image name or the full path to it.  | `w3wp.exe`, `/usr/local/share/dotnet/dotnet` |
| Command Line | The full command line used to launch this process as available to the runtime. | `/Users/acme/some_app/bin/Debug/net7.0/some_app.dll foo=bar` |
| Operating System | OS name and version in a human-readable format. | `macOS Version 12.6.1 (build 21G217)` |
| CPU architecture | See table below. | `arm64` |
| Host | The (optionally fully-qualified) host name. | `MacBook-Pro.localdomain` |
| Time zone | The local time zone in UTC-offset notation. | `UTC+0200` |
| Runtime | Name and version of the executing runtime. | `.NET Framework 4.8.4250.0`|

**CPU Architecture:**

This table provides an exemplary list of well-known values for reporting the CPU architecture.
An agent can decide to use different values that might be readily availalbe to their language/runtime
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

Configuration item names MUST be provided in normalized (lower-case, snake_case) notation.
Configuration value strings MUST be printed in quotes (so accidental leading or trailing whitespace can be spotted).

Agents MUST provide information about following essential configuration items:

| Item | Needs masking | Example |
| - | - | - | - |
| `server_url` | no | `http://localhost:8200` |
| `secret_token` | yes | `[REDACTED]` |
| `api_key` | yes | `[REDACTED]` |
| `service_name` | no | `foo` |
| `log_level` | no | `warning` |

Additional configurations items MAY be logged after that as well.

For each configuration option its **source** SHOULD be reported. These sources can be:

* `default`
* `environment`: Environment variable
* `file`: Configuration file
* `central`: Central Configuration
  * **Note:** Agents MAY print their configuration block again on changed in the central configuration.

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
