## Mobile Events

This document describes event used by the Mobile SDKs using the [OpenTelementry Event Api](https://github.com/open-telemetry/opentelemetry-specification/blob/0a4c6656d1ac1261cfe426b964fd63b1c302877d/specification/logs/event-api.md).
Event names will be recording using the `event.name`


### `ApplicationLaunch` 
This event represents the occurrence of app entering the foreground or background or other application lifecycle states.

#### Attributes
| Name         | Type   | Units | Description            |
|--------------|--------|-------|------------------------|
| `event.name` | String | N/A   | `ApplicationLifecycle` |
| `state`      | String | N/A   | `foreground`           |
| `state.last` | String | N/A   | `background`           |



### Application Non-Responsive (ANR)
This event represents the occurrence of an 'ANR' error reported by the Android OS.

#### Attributes
| Name           | Type | Units | Description |
|----------------|------|-------|-------------|
| `event.name`   |      |       |             |

### `Breadcrumbs`

An event that allows customers to add events to a common `Event` that allows them to retrace users' steps. 

#### Attributes
| Name           | Type    | Units | Description  |
|----------------|---------|-------|--------------|
| `event.name`   | String  | N/A   | `Breadcrumb` |

### Crashes

This event represent a crash event
#### Attributes
| Name           | Type    | Units | Description |
|----------------|---------|-------|-------------|
| `event.name`   | String  | N/A   | `Crash`     |
| `stacktrace`   | String  | N/A   |             | 

### `Application Opens`

An event that represents when an app is opened.

#### Attributes
| Name           | Type   | Units | Description           |
|----------------|--------|-------|-----------------------|
| `event.name`   | String | N/A   | `Application Opened`  |