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

* **Name**: \<method\>, ex: `/helloworld.Greeter/SayHello`
* **Type**: `request`
* **Trace_context**: \<trace-context\>
* **Result**: [\<a-valid-result-value\>](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md#status-codes-and-their-use-in-grpc), ex: `OK`

### Span context

* **Name**: \<method\>, ex: `/helloworld.Greeter/SayHello`
* **Type**: `external`
* **Subtype**: `grpc`
