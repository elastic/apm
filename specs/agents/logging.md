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
