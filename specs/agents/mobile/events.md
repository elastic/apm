## Mobile Events

This document describes event used by the Mobile SDKs using the [OpenTelementry Event Api](https://github.com/open-telemetry/opentelemetry-specification/blob/0a4c6656d1ac1261cfe426b964fd63b1c302877d/specification/logs/event-api.md).
Event names will be recording using the `event.name`


### `ApplicationLaunch` 
This event represents the occurrence of app entering the foreground or background or other application lifecycle states.

#### Attributes
| Name         | Type   | Values                 | Description                                        |
|--------------|--------|------------------------|----------------------------------------------------|
| `event.name` | String | `ApplicationLifecycle` | The name of the event                              |
| `state`      | String | `foreground`           | The lifecycle state the app is transitioning to.   | 
| `state.last` | String | `background`           | The lifecycle state the app is transitioning from. | 



### Application Non-Responsive (ANR)
This event represents the occurrence of an 'ANR' error reported by the Android OS.

#### Attributes
| Name           | Type | Value | Description |
|----------------|------|-------|-------------|
| `event.name`   |      |       |             |

### `Breadcrumbs`

An event that allows customers to add events to a common `Event` that allows them to retrace users' steps. 

#### Attributes
| Name           | Type    | Value        | Description            |
|----------------|---------|--------------|------------------------|
| `event.name`   | String  | `Breadcrumb` | The name of the Event  |

### Crashes

This event represent a crash event

#### Attributes
| Name           | Type    | Values  | Description    |
|----------------|---------|---------|----------------|
| `event.name`   | String  | `Crash` | The event name | 
| `stacktrace`   | String  | N/A     | A Stacktrace   | 

### `Application Opens`

An event that represents when an app is opened.

#### Attributes
| Name           | Type   | Value                | Description    |
|----------------|--------|----------------------|----------------|
| `event.name`   | String | `Application Opened` | The event name | 