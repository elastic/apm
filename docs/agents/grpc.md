# gRPC support in agents

## Header

### Value format
The value format of the header is text, as other vendors use text and there's no advantage to using a binary encoding. See technical details about the gRPC header [here](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#requests).

### Key Names
The header key names are `elastic-apm-traceparent` (for backwards compatibility with older agents) and `traceparent`.

## Instrumented calls
Server and Client Unary request/response calls are instrumented. Support for other calls may be added later (i.e. client/server streaming, bidirectional streaming).

## Transaction/Span context schemas

### Transaction context

* **name**: \<method\>, ex: `/helloworld.Greeter/SayHello`
* **type**: `request`
* **trace_context**: \<trace-context\>
* **result**: [\<a-valid-result-value\>](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md#status-codes-and-their-use-in-grpc), ex: `OK`

### Span context

See [apm#180](https://github.com/elastic/apm/issues/180) and [apm#115](https://github.com/elastic/apm/issues/115) for details on `destination` fields.

* **name**: \<method\>, ex: `/helloworld.Greeter/SayHello`
* **type**: `external`
* **subtype**: `grpc`
* **destination**:
  * **address**: Either an IP (v4 or v6) or a host/domain name.
  * **port**: A port number; Should report default ports.
  * **service**:
    * **resource**: Capture host, and port.
    * **name**: Capture the scheme, host, and non-default port.
    * **type**: Same as `span.type`
