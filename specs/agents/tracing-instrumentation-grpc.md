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

According to the [gRPC status codes reference spec](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md), some
statuses are not used by gRPC client & server, thus some of them should be considered as client-side errors.

The gRPC `UNKNOWN` status refers to an error that is not known, thus we should treat it as a `failure` and NOT map it to
an `unknown` outcome.

For gRPC spans (from the client):

- `OK` : `success`
- anything else: `failure`

For gRPC transactions (from the server):

This mapping can be quite subjective, as we know that some statuses are not used by the gRPC server & client 
implementations and thus their meaning would be application specific. However, we attempt to report as `failure`
outcomes errors that might require attention from the server point of view and report as `success` all the statuses
that are only relevant on the client-side.

| status                    | outcome   | justification                                    |
| ------------------------- | --------- | ------------------------------------------------ |
| `OK`                      | `success` |                                                  |
| `CANCELLED`               | `success` | Operation cancelled by client                    |
| `UNKNOWN`                 | `failure` | Error of an unknown type, but still an error     |
| `INVALID_ARGUMENT` (*)    | `success` | Client-side error                                |
| `DEADLINE_EXCEEDED`       | `failure` |                                                  |
| `NOT_FOUND` (*)           | `success` | Client-side error (similar to HTTP 404)          |
| `ALREADY_EXISTS` (*)      | `success` | Client-side error (similar to HTTP 409)          |
| `PERMISSION_DENIED` (*)   | `success` | Client authentication (similar to HTTP 403)      |
| `RESOURCE_EXHAUSTED` (*)  | `failure` | Likely used for server out of resources          |
| `FAILED_PRECONDITION` (*) | `failure` | Similar to UNAVAILABLE                           |
| `ABORTED` (*)             | `failure` | Similar to UNAVAILABLE                           |
| `OUT_OF_RANGE` (*)        | `success` | Client-side error (similar to HTTP 416)          |
| `UNIMPLEMENTED`           | `success` | Client called a non-implemented feature          |
| `INTERNAL`                | `failure` | Internal error (similar to HTTP 500)             |
| `UNAVAILABLE`             | `failure` | Transient error, client may retry with backoff   |
| `DATA_LOSS` (*)           | `failure` | Lost data should always be reported              |
| `UNAUTHENTICATED` (*)     | `success` | Client-side authentication (similar to HTTP 401) |

The statuses marked with (*) are not used by gRPC libraries and thus their actual meaning is contextual to the
application.

Also, the gRPC status code for a given transaction should be reported in the `transaction.result` field, thus we still have the
capability to detect an abnormal rate of a given status, in a similar way as we do with HTTP 4xx and 5xx errors.
