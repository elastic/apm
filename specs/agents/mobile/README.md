# Introduction

General documentation for the mobile apm agents can be found in [Getting started with APM](https://www.elastic.co/guide/en/apm/get-started/current/overview.html) docs.

The mobile specific docs can be found:

* [iOS Agent](https://www.elastic.co/guide/en/apm/agent/swift/0.x/intro.html)
* Android Agent (TBD)

## Open Telementry
The mobile agents are the first agents at Elastic to be built on top of Open-Telementry. 
A large portion of the mobile agents' functionality can be attributed to the [opentelementry-swift](https://github.com/open-telemetry/opentelemetry-swift) and [opentelementry-java](https://github.com/open-telemtry/opentelemetry-java) packages.

The Open-Telemetry libraries adhere to the semantic conventions outlined in [opentelementry-specifications](https://github.com/open-telemetry/opentelemetry-specification). 
However, the Elastic mobile agents don't set every attribute defined (many only apply to server type monitoring). Additionally, these Open Telementry attributes will be remapped to Elastic specific terms. 

## Semantic Conventions and APM Server Mappings


### Trace Common 
Here is a list of common attributes added onto spans.

| OTel Convention        | Elastic Convention         | Example                          | 
|------------------------|----------------------------|----------------------------------| 
| `service.name`         | `service.name`             | `opbeans-swift`                  |
| `os.description`       | `host.os.platform`         | `iOS Version 15.5 (Build 19F70)` |
| `os.version`           | `labels.os_version`        | `15.5.0`                         |
| `os.name`              | `labels.os_name`           | `iOS`                            |
| `service.namespace`    | `labels.service_namespace` | `co.elastic.opbeans-swift`       | 
| `telemetry.sdk.version` | `agent.version`            | `1.0`                            
| `service.version` | `service.version`          | `5.2.0 (1123)`                   
| `telemetry.sdk.language` | -                          | `swift`                           |
| `telemetry.sdk.name` | -                          | `opentelementry`|
| - | `agent.name` | `iOS/swift` 
| `os.type` | `host.os.platform`         | `darwin` 
| `deivce.id` | `labels.device_id` | `E733F41E-DF47-4BB4-AAF0-FD784FD95653` | 


### `URLSessionInstrumentation` 
| OTel Convention | Elastic convention |
|-----------------|--------------------|
|                 |                    |