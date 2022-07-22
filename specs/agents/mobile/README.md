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

| OTel Convention        | Elastic Convention         | Example                          | Comment                            |
|------------------------|----------------------------|----------------------------------| -----------------------------------|
| [`service.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#service)         | `service.name`             | `opbeans-swift`                  |                                    |     
| [`service.version`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#service)     | `service.version`          | `5.2.0`                          |                                    | 
| [`telemetry.sdk.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#telemetry-sdk)   | `agent.name`               | `iOS`, `android`                 | Elastic's `agent.name` is mapped from:  `telemetry.sdk.name`/`telemetry.sdk.language` |
| [`telemetry.sdk.version`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#telemetry-sdk)| `agent.version`            | `1.0.1`                            |                                  |                 
| [`telemetry.sdk.language`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/#telemetry-sdk)| `service.language.name`   | `swift`, `java`                  | Elastic's `agent.name` is mapped from:  `telemetry.sdk.name`/`telemetry.sdk.language` |
| [`os.description`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)       | `host.os.full`             | `iOS Version 15.5 (Build 19F70)` |                                    |
| [`os.type`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)             | `host.os.platform` and `host.os.type`        | `darwin`                         | :heavy_exclamation_mark: The [APM server also maps](https://github.com/elastic/apm-server/blob/93e2fe20255b1db14c9643fb88caa79e0becf858/processor/otel/metadata.go#L150) `darwin` to the ECS field `host.os.type = macos`. This is wrong for iOS. |
| [`os.version`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)           | :heavy_exclamation_mark: not mapped yet         | `15.5.0`                         | :heavy_exclamation_mark: We should map it to the ECS field `os.version` |
| [`os.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/os/)              | :heavy_exclamation_mark: not mapped yet         | `iOS`, `Android`                         | :heavy_exclamation_mark: We should map it to the ECS field `os.name` |
| [`deployment.environment`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/deployment_environment/) | `service.environment`    | `production`, `dev`              |    |
| [`deivce.id`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/)            | :x: not mapped yet         | `E733F41E-DF47-4BB4-AAF0-FD784FD95653` |  [Follow this description.](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/) (Device ID should be fix and unique for a device but should not carry PII)  |
| [`device.model.identifier`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/) | :heavy_exclamation_mark: not mapped yet      | `iPhone4`,`SM-G920F`             |             |
| [`device.model.name`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/)       | :heavy_exclamation_mark: not mapped yet      | `Samsung Galaxy S6`              |             |
| [`device.manufacturer`](https://opentelemetry.io/docs/reference/specification/resource/semantic_conventions/device/)     | :heavy_exclamation_mark: not mapped yet      | `Apple`, `Samsung`               |             |   


### Common Span attributes
| OTel Convention                         | Elastic Convention         | Example                          | Comment                            |
|-----------------------------------------|----------------------------|----------------------------------| -----------------------------------|
| [Instrumentation name](https://opentelemetry.io/docs/reference/specification/trace/api/#get-a-tracer) |`service.framework.name`| `SwiftUI`, `UIKit` ||
| [Instrumentation version](https://opentelemetry.io/docs/reference/specification/trace/api/#get-a-tracer) |`service.framework.version`| `1.2.3`| |
| [`net.host.connection.type`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.connection.type` | `cell`, `wifi` ||
| [`net.host.connection.subtype`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.connection.subtype` | `lte`, `edge` ||
| [`net.host.carrier.name`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.name` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) ||
| [`net.host.carrier.mcc`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.mcc` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) ||
| [`net.host.carrier.mnc`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.mnc` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) ||
| [`net.host.carrier.icc`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) | `network.carrier.icc` | [see OTEL](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/span-general/) ||

### Additional Span attributes

The following attributes do not have an OpenTelemetry semantic convention:

| Attribute name                          | Elastic Convention         | Example                          | Comment                            |
|-----------------------------------------|----------------------------|----------------------------------| -----------------------------------|
| `telemetry.sdk.elastic_export_timestamp`| N/A: only relevant for APM server.     | `1658149487000000000` | This is required to deal with the time skew on mobile devices. Set this to the timestamp (in nanoseconds) when the span is exported in the OpenTelemetry span processer. :heavy_exclamation_mark: APM server should drop this field and store it in ES.|
| `type` | `transaction.type` | `mobile` :interrobang: | :heavy_exclamation_mark: Need to define new values for transactions resulting from mobile interactions. |
| `session.id`         | :heavy_exclamation_mark: not mapped yet         | `opbeans-swift`                  | Some id for a session. This is not specified in OTel, yet. | 


### Attributes on outgoing HTTP spans 

The span name should have the format: `<method> <host>`.

| OTel Convention          | Elastic convention    | Example        | Comment                            |
|--------------------------|-----------------------|----------------| -----------------------------------|
| [`http.method`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)    | `http.request.method` | `GET`, `POST`  |                                     | 
| [`http.url`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)       | `url.original` and other HTTP-related fields. | `http://localhost:3000/images/products/OP-DRC-C1.jpg` | |
| [`http.target`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)    |  ---                  | `/images/products/OP-DRC-C1.jpg` | Fallback field to derive HTTP-related fields if `http.url` field is not provided. |
| [`http.scheme`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)    |  ---                  | `http`        | Fallback field to derive HTTP-related fields if `http.url` field is not provided.|
| [`net.peer.name`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)  |  ---                  | `localhost`   | Fallback field to derive HTTP-related fields if `http.url` field is not provided.|
| [`net.peer.port`](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/http/)  |  ---                  | `3000`         | Fallback field to derive HTTP-related fields if `http.url` field is not provided. |
