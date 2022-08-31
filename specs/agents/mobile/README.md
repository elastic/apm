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


### Resource Attributes 
Here is a list of resource attributes that are relevant for our mobile agents:

| OTel Convention        | Elastic Convention         | Example                          | Required | Comment                            |
|------------------------|----------------------------|----------------------------------| ---------| -----------------------------------|
| [`service.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#service)         | `service.name`             | `opbeans-swift`                  | :white_check_mark: yes |  |     
| [`service.version`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#service)     | `service.version`          | `5.2.0`                          | :white_check_mark: yes |                             | 
| [`telemetry.sdk.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#telemetry-sdk)   | `agent.name`               | `iOS`, `android`             | :white_check_mark: yes | Elastic's `agent.name` is mapped from:  `telemetry.sdk.name`/`telemetry.sdk.language` |
| [`telemetry.sdk.version`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#telemetry-sdk)| `agent.version`            | `1.0.1`                     | :white_check_mark: yes |    |                 
| [`telemetry.sdk.language`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#telemetry-sdk)| `service.language.name`   | `swift`, `java`              | :white_check_mark: yes | Elastic's `agent.name` is mapped from:  `telemetry.sdk.name`/`telemetry.sdk.language` |
| [`os.description`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)       | `host.os.full`             | `iOS Version 15.5 (Build 19F70)`      | :x: no | |
| [`os.type`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)             | `host.os.platform` | `darwin` | :white_check_mark: yes |  |
| [`os.version`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)           | `host.os.version` | `15.5.0`        | :x: no | |
| [`os.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)              | `host.os.name` and `host.os.type` | `iOS`, `Android`   | :white_check_mark: yes |  |
| [`deployment.environment`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/deployment_environment/) | `service.environment`    | `production`, `dev`              | :x: no |    |
| [`deivce.id`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/)        | `device.id`        | `E733F41E-DF47-4BB4-AAF0-FD784FD95653` | :x: no |  [Follow this description.](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/) (Device ID should be fix and unique for a device but should not carry PII)  |
| [`device.model.identifier`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/) | `device.model.identifier` | `iPhone4`,`SM-G920F`            | :x: no  |             |
| [`device.model.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/)       | `device.model.name` | `Samsung Galaxy S6`            | :x: no  | This information is potentially not directly available on the device and needs to be derived / mapped from `device.model.identifier`. In this case, the APM server should do the mapping. |
| [`device.manufacturer`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/)     | `device.manufacturer` | `Apple`, `Samsung`            | :x: no  |  This information is potentially not directly available on the device and needs to be derived / mapped from `device.model.identifier`. In this case, the APM server should do the mapping. |   
| [`process.runtime.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/process/#process-runtimes) | `service.runtime.name` | `Android Runtime` | :x: no | Use `Android Runtime` for Android.  |
| [`process.runtime.version`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/process/#process-runtimes) | `service.runtime.version` | `2.0.1` | :x: no | Use the Dalvik version for Android (`System.getProperty("java.vm.version")`).  |

### Common Span attributes
| OTel Convention                         | Elastic Convention         | Example                          | Required | Comment                            |
|-----------------------------------------|----------------------------|----------------------------------| ---------| ---------------------------------|
| [Instrumentation name / tracer name](https://opentelemetry.io/docs/reference/specification/trace/api/#get-a-tracer) |`service.framework.name`| `SwiftUI`, `UIKit` | :x: no | Use the name of the library that is instrumented.|
| [Instrumentation version / tracer version](https://opentelemetry.io/docs/reference/specification/trace/api/#get-a-tracer) |`service.framework.version`| `1.2.3`| :x: no | Use the version of the library that is instrumented. |
| [`net.host.connection.type`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.connection.type` | `cell`, `wifi` | :x: no||
| [`net.host.connection.subtype`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.connection.subtype` | `lte`, `edge` | :x: no||
| [`net.host.carrier.name`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.name` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | :x: no||
| [`net.host.carrier.mcc`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.mcc` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | :x: no||
| [`net.host.carrier.mnc`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.mnc` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | :x: no||
| [`net.host.carrier.icc`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.icc` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | :x: no||

### Additional Span attributes

The following attributes do not have an OpenTelemetry semantic convention:

| Attribute name                          | Elastic Convention         | Example                          | Required | Comment                            |
|-----------------------------------------|----------------------------|----------------------------------| ---------| ---------------------------------|
| `telemetry.sdk.elastic_export_timestamp`| N/A: only relevant for APM server.     | `1658149487000000000` | :white_check_mark: yes | This is required to deal with the time skew on mobile devices. Set this to the timestamp (in nanoseconds) when the span is exported in the OpenTelemetry span processer. |
| `type` | `transaction.type` | `mobile` :interrobang: | :white_check_mark: yes | :heavy_exclamation_mark: Need to define new values for transactions resulting from mobile interactions. |
| `session.id`         | :heavy_exclamation_mark: not mapped yet         | `opbeans-swift`                  | :x: no | Some id for a session. This is not specified in OTel, yet. | 


### Attributes on outgoing HTTP spans 

The span name should have the format: `<method> <host>`.

| OTel Convention          | Elastic convention    | Example        | Required | Comment                            |
|--------------------------|-----------------------|----------------| ---------| -----------------------------------|
| [`http.method`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)    | `http.request.method` | `GET`, `POST`   | :white_check_mark: yes |                                     | 
| [`http.url`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)       | `url.original` and other HTTP-related fields. | `http://localhost:3000/images/products/OP-DRC-C1.jpg`  | :x: no| |
| [`http.target`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)    |  ---                   | `/images/products/OP-DRC-C1.jpg` |  :x: no | Fallback field to derive HTTP-related fields if `http.url` field is not provided. |
| [`http.scheme`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)    |  ---                  | `http`         | :x: no| Fallback field to derive HTTP-related fields if `http.url` field is not provided.|
| [`net.peer.name`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)  |  ---                  | `localhost`    | :x: no| Fallback field to derive HTTP-related fields if `http.url` field is not provided.|
| [`net.peer.port`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)  |  ---                  | `3000`          | :x: no| Fallback field to derive HTTP-related fields if `http.url` field is not provided. |
