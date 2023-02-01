## Mobile Events

This document describes event used by the Mobile SDKs using the [OpenTelementry Event Api](https://github.com/open-telemetry/opentelemetry-specification/blob/0a4c6656d1ac1261cfe426b964fd63b1c302877d/specification/logs/event-api.md).
All events collected by the mobile agents should set the `event.domain` to `device`.
Event names will be recording using the `event.name`

### Crashes

This event represent a crash event

#### Attributes

| Name                   | Type   | Values               | Description            |
|------------------------|--------|----------------------|------------------------|
| `event.name`           | String | `crash`              | The event name.        | 
| `event.domain`         | String | `device`             | the event domain.      |
| `exception.message`    | String | `Division by zero`   | The exception message. |  
| `exception.stacktrace` | String |                      | A Stacktrace.          |
| `exception.type`       | String | `OSError`, `SIGSEGV` | The exception type.    |
