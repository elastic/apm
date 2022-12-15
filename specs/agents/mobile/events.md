## Mobile Events

This document describes event used by the Mobile SDKs using the [OpenTelementry Event Api](https://github.com/open-telemetry/opentelemetry-specification/blob/0a4c6656d1ac1261cfe426b964fd63b1c302877d/specification/logs/event-api.md).
All events collected by the mobile agents should set the `event.domain` to `device`.
Event names will be recording using the `event.name`

### Application Lifecycle events 
These event represents the occurrence of app entering the foreground or background or other application lifecycle states.
The precise names of these events are still to be determined. They may mirror the lifecycle events their respective mobile platforms.

| Name           | Type   | Values   | Description                                        |
|----------------|--------|----------|----------------------------------------------------|
| `event.name`   | String | tbd      | The name of the event                              |
| `event.domain` | String | `device` | The lifecycle state the app is transitioning to.   | 



### Application Non-Responsive (ANR)
This event represents the occurrence of an 'ANR' error reported by the Android OS.

#### Attributes
| Name           | Type | Value | Description |
|----------------|------|-------|-------------|
| `event.name`   |   String   |   `anr`    |      The app's UI thread has been blocked for longer than it should.      |

### `Breadcrumbs`

An event that allows customers to add events to a common `Event` that allows them to retrace users' steps. 

#### Attributes
| Name           | Type    | Value        | Description            |
|----------------|---------|--------------|------------------------|
| `event.name`   | String  | `breadcrumb` | The name of the Event  |

### Crashes

This event represent a crash event

#### Attributes

| Name           | Type    | Values  | Description       |
|----------------|---------|---------|-------------------|
| `event.name`   | String  | `crash` | The event name    | 
| `event.domain` | String | `device` | the event domain  |
| `stacktrace`   | String  | N/A     | A Stacktrace      |


