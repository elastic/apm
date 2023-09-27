## Synthetics Integration

Synthetic monitors play a crucial role in periodically checking the status of your services and applications on a global scale. General documentation about synthetic monitors can be found in
[Synthetics getting started page](https://www.elastic.co/guide/en/observability/current/synthetics-get-started.html).

This integration goes in to more detail about how the sythetics monitors would
be correlated with the APM traces. Synthetics traces can be categorized in to two
main types
  1. HTTP checks - These have one-one mapping with APM transactions
  2. Browser checks - These have a one-to-many mapping with APM transactions

### Correlation

The Synthetics agent (including Heartbeat) takes the responsibility of creating the
[`traceparent`](../agents/tracing-distributed-tracing.md#trace_id-parent_id-and-traceparent)
header for each outgoing network request associated with a test during every
monitor execution.

- `trace.id` and `parent.id`
  - outgoing requests that are being explicity traced by the synthetics agent
     will have the `parent.id` and `trace.id` as part of the trace context.
  - must be unique for each step for a browser monitor
  - must be unique for a http monitor
- `sampled` Flag
  - used to control the sampling decision for all the downstream services.
  - 100% sampling when tracing is enabled

#### Browser checks

When executing a Synthetics journey with APM tracing enabled for specific URLs
using the --apm_tracing_urls flag, the Synthetics agent takes the following
actions:

1. Adds the traceparent header to each matching outgoing request.
2. Includes trace.id and parent.id in all the Step Elasticsearch (ES) documents for the journey.

```ts
// run journey
npx @elastic/synthetics --apm_tracing_urls "elastic.co/*" 

// example.journey.ts
journey("elastic e2e", ({ page }) => {
  step("home page", async() => {
    await page.goto("https://www.elastic.co")
  })
  step("blog page", async() => {
    await page.goto("https://www.elastic.co/blog")
  })
})
```

Example of the tracing information added to the ES documents for two steps in the journey:

```json
// Step - homepage
{"type":"step/end","journey":{"name":"elastic e2e"},"step":{"name":"home page","index":1,"status":"failed","duration":{"us":17382122}}, "trace.id": "t1"}
{"type":"journey/network_info","journey":{"name":"elastic e2e"},"step":{"name":"home page","index":1},"http":{"request":{"url":"http://www.elastic.co/","method":"GET"}},"trace.id": "t1", "span.id": "s1"}


// Step - blog page
{"type":"step/end","journey":{"name":"elastic e2e"},"step":{"name":"blog page","index":2,"status":"failed","duration":{"us":17382122}}, "trace.id": "t2"}
{"type":"journey/network_info","journey":{"name":"elastic e2e"},"step":{"name":"blog page","index":2},"http":{"request":{"url":"http://www.elastic.co/blog","method":"GET"}},"trace.id": "t2", "span.id": "s2"}
```

With this tracing information available in the ES documents for each step's network requests, the Synthetics UI can link back to the individual backend transactions in APM.

#### HTTP Checks

For the below HTTP monitor

```yml
# heartbeat.yml
heartbeat.monitors:
- type: http
  id: test-http
  urls: ["https://www.example.com"]
  apm:
    enabled: true
```

Heartbeat would add the `traceparent` header to the monitored URL and add the
other tracing related information to the ES documents.

```json
{"event":{"action":"monitor.run"},"monitor":{"id":"test-http","type":"http","status":"up","duration":{"ms":112}}, "trace.id": "t1", "span.id": "s1"}
```

It's important to note that there is no dedicated waterfall information for the HTTP checks in the Synthetics UI. Consequently, the linking here will directly take you to the APM transaction if the backend is also traced by Elastic APM or OTEL (OpenTelemetry)-based agents.

**NOTE: The correlation remain applicable even if downstream services are traced by OpenTelemetry (OTel)-based agents. This ensures a consistent and seamless tracing experience regardless of the underlying tracing infrastructure.**

### Identifying Synthetics trace

Synthetics monitor executions creates `rootless traces` as these traces are not
reported to the APM server. To overcome this limitation on the APM UI, we need
to identify the synthetics traces and explicity link them to the Synthetics
waterfall view. 

- `http.headers.user-agent`:
  - Contains `Elastic/Synthetics` for all outgoing requests from Synthetis based monitors.

There is a limitation with this approach
- users can override the `User-Agent` header in the monitor configuration which
  might lead to users seeing only partial traces on the APM UI.

We can also add a foolproof solution by introducing vendor specific `tracestate`
property.
However, this property would need special handling in our agents and wouldn't be recognized by vanilla OpenTelemetry agents.

- `tracestate`:
  - Contains `es:origin=synthetics` for all outgoing requests from Synthetis based monitors.


When a trace is confirmed to be originated from Synthetics-based monitors, the
Trace Explorer view can be linked back to the Synthetics waterfall view.

- `/app/synthetics/link-to/<trace.id>:span.id`
  - links back to the explicit browser waterfall step on the Synthetics UI, and
    it follows the format `/monitor/:monitorId/test-run/:runId/step/:stepIndex#:spanId`.