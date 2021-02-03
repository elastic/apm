## gRPC support in agents

### Header

#### Value format
The value format of the header is text, as other vendors use text and there's no advantage to using a binary encoding. See technical details about the gRPC header [here](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#requests).

#### Key Names
The header key names are `elastic-apm-traceparent` (for backwards compatibility with older agents) and `traceparent`.

### Instrumented calls
Server and Client Unary request/response calls are instrumented. Support for other calls may be added later (i.e. client/server streaming, bidirectional streaming).

### Transaction/Span context schemas

#### Transaction context

* **name**: \<method\>, ex: `/helloworld.Greeter/SayHello`
* **type**: `request`
* **trace_context**: \<trace-context\>
* **result**: [\<a-valid-result-value\>](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md#status-codes-and-their-use-in-grpc), ex: `OK`
* **outcome**: See [Outcome](#outcome)

#### Span context

Note that the destination fields are optional as some gRPC libraries don't expose host and port information.
See [apm#180](https://github.com/elastic/apm/issues/180) and [apm#115](https://github.com/elastic/apm/issues/115) for details on `destination` fields.

* **name**: \<method\>, ex: `/helloworld.Greeter/SayHello`
* **type**: `external`
* **subtype**: `grpc`
* **outcome**: See [Outcome](#outcome)
* **destination**:
  * **address**: Either an IP (v4 or v6) or a host/domain name.
  * **port**: A port number; Should report default ports.
  * **service**:
    * **resource**: Capture host, and port.
    * **name**: Capture the scheme, host, and non-default port.
    * **type**: Same as `span.type`

#### Outcome

With gRPC, transaction and span outcome is set from gRPC response status.

If such status is not available, then we default to the following:

- `failure` if an error is reported
- `success` otherwise

According to the [gRPC status codes reference spec](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md), The
following statuses are not used by gRPC client & server, thus they should be considered as client-side errors.

The `UNKNOWN` status refers to an error that is not known to the protocol, thus we should treat it as a `failure`.

For gRPC spans (from the client):

- `OK` : `success`
- anything else: `failure`

For gRPC transactions (from the server):

- `OK` : `success`
- `CANCELLED` : `failure`
- `UNKNOWN` : `failure`
- `INVALID_ARGUMENT` : `success` (*)
- `DEADLINE_EXCEEDED` : `failure`
- `NOT_FOUND` : `success` (*)
- `ALREADY_EXISTS` : `success` (*)
- `PERMISSION_DENIED` : `success` (*)
- `RESOURCE_EXHAUSTED` : `failure`
- `FAILED_PRECONDITION` : `success` (*)
- `ABORTED` : `success` (*)
- `OUT_OF_RANGE` : `success` (*)
- `UNIMPLEMENTED` : `failure`
- `INTERNAL` : `failure`
- `UNAVAILABLE` : `failure`
- `DATA_LOSS` : `success` (*)
- `UNAUTHENTICATED` : `success` (*)

The statuses marked with (*) are not used by gRPC libraries and are treated as client errors.