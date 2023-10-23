## Transport

Agents send data to the APM Server as JSON (application/json) or ND-JSON (application/x-ndjson) over HTTP. We describe here various details to guide transport implementation.

### User-Agent

In order to help debugging and gathering usage statistics, agents should use one of the following values for the `User-Agent` HTTP header:

- Header value should start with agent github repository as prefix and version `apm-agent-${language}/${agent.version}`.
- If both `service.name` and `service.version` are set, append ` (${service.name} ${service.version})`
- If only `service.name` is set, append `(${service.name})`

An executable gherkin specification is also provided in [user_agent.feature](../../tests/agents/gherkin-specs/user_agent.feature).

Examples:
- `apm-agent-java/v1.25.0`
- `apm-agent-ruby/4.4.0 (myservice)`
- `apm-agent-python/6.4.0 (myservice v42.7)`

### Background sending

In order to avoid impacting application performance and behaviour, agents should (where possible) send data in a non-blocking manner, e.g. via a background thread/goroutine/process/what-have-you, or using asynchronous I/O.

If data is sent in the background process, then there must be some kind of queuing between that background process and the application code. The queue should be limited in size to avoid memory exhaustion. In the event that the queue fills up, agents must drop events: either drop old events or simply stop recording new events.

### Batching/streaming data

With the exception of the RUM agent (which does not maintain long-lived connections to the APM Server), agents should use the ND-JSON format. The ND-JSON format enables agents to stream data to the server as it is being collected, with one event being encoded per line. This format is supported since APM Server 6.5.0.

Agents should implement one of two methods for sending events to the server:

 - batch events together and send a complete request after a given size is reached, or amount of time has elapsed
 - start streaming events immediately to the server using a chunked-encoding request, and end the request after a given amount of data has been sent, or amount of time has elapsed

The streaming approach is preferred. There are two configuration options that agents should implement to control when data is sent:

 - [ELASTIC_APM_API_REQUEST_TIME](https://www.elastic.co/guide/en/apm/agent/python/current/configuration.html#config-api-request-time)
 - [ELASTIC_APM_API_REQUEST_SIZE](https://www.elastic.co/guide/en/apm/agent/python/current/configuration.html#config-api-request-size)

All events can be streamed as described in the [Intake API](https://www.elastic.co/guide/en/apm/server/current/intake-api.html) documentation. Each line encodes a single event, with the first line in a stream encoding the special metadata "event" which is folded into all following events. This metadata "event" is used to describe static properties of the system, process, agent, etc.

When the batching approach is employed, unhandled exceptions/unexpected errors should typically be sent immediately to ensure timely error visibility, and to avoid data loss due to process termination. Even when using streaming there may be circumstances in which the agent should block the application until events are sent, but this should be both rare and configurable, to avoid interrupting normal program operation. For example, an application may terminate itself after logging a message at "fatal" level. In such a scenario, it may be useful for the agent to optionally block until enqueued events are sent prior to process termination.

### Transport errors

If the HTTP response status code isn’t 2xx or if a request is prematurely closed (either on the TCP or HTTP level) the request MUST be considered failed.

When a request fails, the agent has no way of knowing exactly what data was successfully processed by the APM Server. And since the agent doesn’t keep a copy of the data that was sent, there’s no way for the agent to re-send any data. Furthermore, as the data waiting to be sent is already compressed, it’s impractical to recover any of it in a way so that it can be sent over a new HTTP request.

The agent should therefore drop the entire compressed buffer: both the internal zlib buffer, and potentially the already compressed data if such data is also buffered. Data subsequently written to the compression library can be directed to a new HTTP request.

The new HTTP request should not necessarily be started immediately after the previous HTTP request fails, as the reason for the failure might not have been resolved up-stream. Instead an incremental back-off algorithm SHOULD be used to delay new requests. The grace period should be calculated in seconds using the algorithm `min(reconnectCount++, 6) ** 2 ± 10%`, where `reconnectCount` starts at zero. So the delay after the first error is 0 seconds, then circa 1, 4, 9, 16, 25 and finally 36 seconds. We add ±10% jitter to the calculated grace period in case multiple agents entered the grace period simultaneously. This way they will not all try to reconnect at the same time.

Agents should support specifying multiple server URLs. When a transport error occurs, the agent should switch to another server URL at the same time as backing off.

While the grace period is in effect, the agent may buffer the data that was supposed to be sent if the grace period wasn’t in effect. If buffering, the agent must ensure the memory used to buffer data data does not grow indefinitely.

### Compression

The APM Server accepts both uncompressed and compressed HTTP requests. The following compression formats are supported:

- zlib data format (`Content-Encoding: deflate`)
- gzip data format (`Content-Encoding: gzip`)

Agents MUST compress the HTTP payload and SHOULD optimize for speed over compactness (typically known as the "best speed" level).

If the host part of the APM Server URL is either `localhost`, `127.0.0.1`, `::1`, or `0:0:0:0:0:0:0:1`, agents SHOULD disable compression.
Agents MUST NOT use the compression level `NO_COMPRESSION` to disable compression.
That's because the [Lambda extension](https://github.com/elastic/apm-aws-lambda/tree/main/apm-lambda-extension)
would otherwise consider the data as being compressed (due to the `Content-Encoding` header) and send data to APM Server that's actually uncompressed.

### `context_propagation_only` configuration

|                |   |
|----------------|---|
| Type           | `boolean` |
| Default        | `false` |
| Dynamic        | `true` |
| Central config | `true` |

Agents MAY implement this configuration option.
`context_propagation_only` is a boolean configuration option to have an APM
agent perform trace-context propagation and log correlation *only*; and to
explicitly *not* send event data to APM server. This allows an application to
get automatic context propagation and log correlation, **without** having
deployed an APM server for event collection.

Agents that implement this configuration option:

- MUST continue to propagate trace headers (`traceparent`, `tracestate`, etc.)
  per normal;
- MUST start a trace-id if no `traceparent` header is present where they would normally start a transaction and propagate it.
- MUST continue to support [log correlation](./log-correlation.md);
- MUST NOT send event data to the APM server
- SHOULD attempt to reduce runtime overhead where possible. For example,
  because events will be dropped there is no need to collect stack traces,
  collect metrics, calculate breakdown metrics, or to create spans (other than
  the top-level transaction required for context propagation, similarly to non-sampled traces).


### `disable_send` configuration

Agents MAY implement this configuration option.
`disable_send` is a boolean configuration option to have an APM agent be fully
functioning, but not communicate with an APM server. Use case for this include
testing and continuous integration (CI) systems.

Agents that implement this configuration option:

- MUST NOT attempt to communicate with APM server. This includes central configuration.
- MUST NOT log warnings/errors related to failures to communicate with APM server.
- SHOULD otherwise perform all functions.
