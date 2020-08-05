# Building an agent  <!-- omit in toc -->

So you want to build an agent for Elastic APM? That's great, here's what you need to know.

**Note:** This is a living document. If you come across something weird or find something missing, please add it or ask open an issue.

---

# Introduction  <!-- omit in toc -->

The [Getting started with APM](https://www.elastic.co/guide/en/apm/get-started/current/overview.html) provides an overview to understand the big picture architecture.

Your agent will be talking to the APM Server using HTTP, sending data to it as JSON or ND-JSON. There are multiple categories of data that each agent captures and sends to the APM Server:

  - Trace data: transactions and spans (distributed tracing)
  - Errors/exceptions (i.e. for error tracking)
  - Metrics (host process-level metrics, and language/runtime-specific metrics)

You can find details about each of these in the [APM Data Model](https://www.elastic.co/guide/en/apm/get-started/current/apm-data-model.html) documentation. The [Intake API](https://www.elastic.co/guide/en/apm/server/current/intake-api.html) documentation describes the wire format expected by APM Server. APM Server converts the data into Elasticsearch documents, and then the APM UI in Kibana provides visualisations over that data, as well as enabling you to dig into the data in an interactive way.

# Guiding Philosophy  <!-- omit in toc -->

1. Agents try to be as good citizens as possible in the programming language they are written for. Even though every language ends up reporting to the same server API with the same JSON format, the agents should try to make as much sense in the context of the relevant language as possible. We want to both streamline the agents to work the same in every context **but** also make them feel like they were built specifically for each language. It's up to you to figure out how this looks in the language you are writing your agent for.

2. Agents should be as close to zero configuration as possible.

  - Use sensible defaults, aligning across agents unless there is a compelling reason to have a language-specific default.
  - Agents should typically come with out-of-the-box instrumentation for the most popular frameworks or libraries of their relevant language.
  - Users should be able to disable specific instrumentation modules to reduce overhead, or where details are not interesting to them.

3. The overhead of agents must be kept to a minimum, and must not affect application behaviour.

# Features to implement  <!-- omit in toc -->

<!-- toc -->

- [Transport](#Transport)
  - [Background sending](#Background-sending)
  - [Batching/streaming data](#Batchingstreaming-data)
  - [Transport errors](#Transport-errors)
  - [Compression](#Compression)
- [Metadata](#Metadata)
  - [System metadata](#System-metadata)
    - [Container/Kubernetes metadata](#ContainerKubernetes-metadata)
  - [Process metadata](#Process-metadata)
  - [Service metadata](#Service-metadata)
  - [Global labels](#Global-labels)
- [Tracing](#Tracing)
  - [Transactions](#Transactions)
    - [HTTP Transactions](#HTTP-Transactions)
    - [Transaction sampling](#Transaction-sampling)
  - [Spans](#Spans)
    - [Span stack traces](#Span-stack-traces)
    - [Span count](#Span-count)
    - [HTTP client spans](#HTTP-client-spans)
    - [Database spans](#Database-spans)
      - [Database span names](#Database-span-names)
      - [Database span type/subtype](#Database-span-typesubtype)
  - [Manual APIs](#Manual-APIs)
  - [Distributed Tracing](#Distributed-Tracing)
    - [HTTP Headers](#HTTP-Headers)
    - [Binary Fields](#Binary-Fields)
- [Error/exception tracking](#Errorexception-tracking)
- [Metrics](#Metrics)
  - [System/process CPU/Heap](#Systemprocess-CPUHeap)
  - [cgroup metrics](#cgroup-metrics)
  - [Runtime](#Runtime)
  - [Transaction and span breakdown](#Transaction-and-span-breakdown)
- [Logging Correlation](#Logging-Correlation)
- [Agent Configuration](#Agent-Configuration)
  - [APM Agent Configuration via Kibana](#APM-Agent-Configuration-via-Kibana)
    - [Interaction with local config](#Interaction-with-local-config)
    - [Caching](#Caching)
    - [Dealing with errors](#Dealing-with-errors)

<!-- tocstop -->

## Transport

Agents send data to the APM Server as JSON (application/json) or ND-JSON (application/x-ndjson) over HTTP. We describe here various details to guide transport implementation.

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

Agents should compress the HTTP payload by default, optimising for speed over compactness (typically known as the "best speed" level).

## Metadata

As mentioned above, the first "event" in each ND-JSON stream contains metadata to fold into subsequent events. The metadata that agents should collect includes are described in the following sub-sections.

 - service metadata
 - global labels (requires APM Server 7.2 or greater)

The process for proposing new metadata fields is detailed
[here](new-fields.md).

### System metadata

System metadata relates to the host/container in which the service being monitored is running:

 - hostname
 - architecture
 - operating system
 - container ID
 - kubernetes
   - namespace
   - node name
   - pod name
   - pod UID

#### Container/Kubernetes metadata

On Linux, the container ID and some of the Kubernetes metadata can be extracted by parsing `/proc/self/cgroup`. For each line in the file, we split the line according to the format "hierarchy-ID:controller-list:cgroup-path", extracting the "cgroup-path" part. We then attempt to extract information according to the following algorithm:

 1. Split the path into dirname/basename (i.e. on the final slash)

 2. If the basename ends with ".scope", check for a hyphen and remove everything up to and including that. This allows us to match `.../docker-<container-id>.scope` as well as `.../<container-id>`.

 3. Attempt to extract the Kubernetes pod UID from the dirname by matching one of the following regular expressions:
     - `(?:^/kubepods[\\S]*/pod([^/]+)$)`
     - `(?:^/kubepods\.slice/kubepods-[^/]+\.slice/kubepods-[^/]+-pod([^/]+)\.slice/$)`

    The capturing group in either case is the pod UID. In the latter case, which occurs when using the systemd cgroup driver, we must unescape underscores (`_`) to hyphens (`-`) in the pod UID.
    If we match a pod UID then we record the hostname as the pod name since, by default, Kubernetes will set the hostname to the pod name. Finally, we record the basename as the container ID without any further checks.

 4. If we did not match a Kubernetes pod UID above, then we check if the basename matches one of the following regular expressions:

    - `^[[:xdigit:]]{64}$`
    - `^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4,}$`

    If we match, then the basename is assumed to be a container ID.

If the Kubernetes pod name is not the hostname, it can be overridden by the `KUBERNETES_POD_NAME` environment variable, using the [Downward API](https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/). In a similar manner, you can inform the agent of the node name and namespace, using the environment variables `KUBERNETES_NODE_NAME` and `KUBERNETES_NAMESPACE`.

### Process metadata

Process level metadata relates to the process running the service being monitored:

 - process ID
 - parent process ID
 - process arguments
 - process title (e.g. "node /app/node_")

### Service metadata

Service metadata relates to the service/application being monitored:

 - service name and version
 - environment name ("production", "development", etc.)
 - agent name (e.g. "ruby") and version (e.g. "2.8.1")
 - language name (e.g. "ruby") and version (e.g. "2.5.3")
 - runtime name (e.g. "jruby") and version (e.g. "9.2.6.0")
 - framework name (e.g. "flask") and version (e.g. "1.0.2")

For official Elastic agents, the agent name should just be the name of the language for which the agent is written, in lower case.

### Cloud Provider Metadata

[Cloud provider metadata](https://github.com/elastic/apm-server/blob/master/docs/spec/cloud.json)
is collected from local cloud provider metadata services:

- availability_zone
- account
  - id
  - name
- instance
  - id
  - name
- machine.type
- project
  - id
  - name
- provider
- region

This metadata collection is controlled by a configuration value,
`CLOUD_PROVIDER`. The default is `auto`, which automatically detects the cloud
provider. If set to `none`, no cloud metadata will be generated. If set to
any of `aws`, `gcp`, or `azure`, metadata will only be generated from the
chosen provider.

Any intake API requests to the APM server should be delayed until this
metadata is available.

A sample implementation of this metadata collection is available in
[the Python agent](https://github.com/elastic/apm-agent-python/blob/master/elasticapm/utils/cloud.py).

### Global labels

Events sent by the agents can have labels associated, which may be useful for custom aggregations, or document-level access control. It is possible to add "global labels" to the metadata, which are labels that will be applied to all events sent by an agent. These are only understood by APM Server 7.2 or greater.

Global labels can be specified via the environment variable `ELASTIC_APM_GLOBAL_LABELS`, formatted as a comma-separated list of `key=value` pairs.

## Tracing

### Transactions

#### HTTP Transactions

Agents should instrument HTTP request routers/handlers, starting a new transaction for each incoming HTTP request. When the request ends, the transaction should be ended, recording its duration.

- The transaction `type` should be `request`.
- The transaction `result` should be `HTTP Nxx`, where N is the first digit of the status code (e.g. `HTTP 4xx` for a 404)
- The transaction `name` should be aggregatable, such as the route or handler name. Examples:

    - `GET /users/{id}`
    - `UsersController#index`

It's up to you to pick a naming scheme that is the most natural for the language or web framework you are instrumenting.

In case a name cannot be automatically determined, and a custom name has not been provided by other means, the transaction should be named `<METHOD> unknown route`, e.g. `POST unknown route`. This would normally also apply to requests to unknown endpoints, e.g. the transaction for the request `GET /this/path/does/not/exist` would be named `GET unknown route`, whereas the transaction for the request `GET /users/123` would still be named `GET /users/{id}` even if the id `123` did not match any known user and the request resulted in a 404.

In addition to the above properties, HTTP-specific properties should be recorded in the transaction `context`, for sampled transactions only. Refer to the [Intake API Transaction](https://www.elastic.co/guide/en/apm/server/current/transaction-api.html) documentation for a description of the various context fields.

By default request bodies are not captured. It should be possible to configure agents to enable their capture using the config variable `ELASTIC_APM_CAPTURE_BODY`. By default agents will capture request headers, but it should be possible to disable their capture using the config variable `ELASTIC_APM_CAPTURE_HEADERS`.

Request and response headers, cookies, and form bodies should be sanitised (i.e. secrets removed). Each agent should define a default list of keys to sanitise, which should include at least the following (using wildcard matching):

  - `password`
  - `passwd`
  - `pwd`
  - `secret`
  - `*key`
  - `*token*`
  - `*session*`
  - `*credit*`
  - `*card*`
  - `authorization`
  - `set-cookie`

Agents may may include additional patterns if there are common conventions specific to language frameworks.

#### Transaction sampling

To reduce processing and storage overhead, transactions may be "sampled". Currently sampling has the effect of limiting the amount of data we capture for transactions: for non-sampled transactions instrumentation should not record context, nor should any spans be captured. The default graphs in the APM UI will utilise the transaction properties available for both sampled and non-sampled transactions.

By default all transactions will be sampled. Agents can be configured to sample probabilistically, by specifying a sampling
probability in the range \[0,1\] using the configuration `ELASTIC_APM_TRANSACTION_SAMPLE_RATE`. For example:

 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0` means no transactions will be sampled
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=1` means all transactions will be sampled (the default)
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0.5` means approximately 50% of transactions will be sampled

For more details on how to implement sampling in agents, see the separate [sampling](sampling.md) specification.

### Spans

The agent should also have a sense of the most common libraries for these and instrument them without any further setup from the app developers.

#### Span stack traces

Spans may have an associated stack trace, in order to locate the associated source code that caused the span to occur. If there are many spans being collected this can cause a significant amount of overhead in the application, due to the capture, rendering, and transmission of potentially large stack traces. It is possible to limit the recording of span stack traces to only spans that are slower than a specified duration, using the config variable `ELASTIC_APM_SPAN_FRAMES_MIN_DURATION`.

#### Span count

When a span is started a counter should be incremented on its transaction, in order to later identify the _expected_ number of spans. In this way we can identify data loss, e.g. because events have been dropped, or because of instrumentation errors.

To handle edge cases where many spans are captured within a single transaction, the agent should enable the user to start dropping spans when the associated transaction exeeds a configurable number of spans. When a span is dropped, it is not reported to the APM Server, but instead another counter is incremented to track the number of spans dropped. In this case the above mentioned counter for started spans is not incremented.

```json
"span_count": {
  "started": 500,
  "dropped": 42
}
```

Here's how the limit can be configured for [Node.js](https://www.elastic.co/guide/en/apm/agent/nodejs/current/agent-api.html#transaction-max-spans) and [Python](https://www.elastic.co/guide/en/apm/agent/python/current/configuration.html#config-transaction-max-spans).

#### HTTP client spans

We capture spans for outbound HTTP requests. These should have a type of `external`, and subtype of `http`. The span name should have the format `<method> <host>`.

For outbound HTTP request spans we capture the following http-specific span context:

- `http.url` (the target URL)
- `http.status_code` (the response status code)

The captured URL should have the userinfo (username and password), if any, redacted.

#### Database spans

We capture spans for various types of database/data-stores operations, such as SQL queries, Elasticsearch queries, Redis commands, etc. We follow some of the same conventions defined by OpenTracing for capturing database-specific span context, including:

 - `db.instance`: database instance name, e.g. "customers"
 - `db.statement`: statement/query, e.g. "SELECT * FROM foo"
 - `db.user`: username used for database access, e.g. "readonly_user"
 - `db.type`: database type/category, which should be "sql" for SQL databases, and the lower-cased database name otherwise.

The full database statement should be stored in `db.statement`, which may be useful for debugging performance issues. We store up to 10000 Unicode characters per database statement.

For SQL databases this will be the full SQL statement.

For MongoDB, this can be set to the command encoded as MongoDB Extended JSON.

For Elasticsearch search-type queries, the request body may be recorded. Alternatively, if a query is specified in HTTP query parameters, that may be used instead. If the body is gzip-encoded, the body should be decoded first.

##### Database span names

For SQL operations we perform a limited parsing the statement, and extract the operation name and outer-most table involved (if any). See more details here: https://docs.google.com/document/d/1sblkAP1NHqk4MtloUta7tXjDuI_l64sT2ZQ_UFHuytA.

For Redis, the the span name can simply be set to the command name, e.g. `GET` or `LRANGE`.

For MongoDB, the span name should be the command name in the context of its collection/database, e.g. `users.find`.

For Elasticsearch, the span name should be `Elasticsearch: <method> <path>`, e.g.
`Elasticsearch: GET /index/_search`.

##### Database span type/subtype

For database spans, the type should be `db` and subtype should be the database name. Agents should standardise on the following span subtypes:

- `postgresql` (PostgreSQL)
- `mysql` (MySQL)

### Manual APIs

All agents must provide an API to enable developers to instrument their applications manually, in addition to any automatic instrumentation. Agents document their APIs in the elastic.co docs:

- [Node.js Agent](https://www.elastic.co/guide/en/apm/agent/nodejs/current/api.html)
- [Go Agent](https://www.elastic.co/guide/en/apm/agent/go/current/api.html)
- [Java Agent](https://www.elastic.co/guide/en/apm/agent/java/current/public-api.html)
- [.NET Agent](https://www.elastic.co/guide/en/apm/agent/dotnet/current/public-api.html)
- [Python Agent](https://www.elastic.co/guide/en/apm/agent/python/current/api.html)
- [Ruby Agent](https://www.elastic.co/guide/en/apm/agent/ruby/current/api.html)
- [RUM JS Agent](https://www.elastic.co/guide/en/apm/agent/js-base/current/api.html)

In addition to each agent having a "native" API for instrumentation, they also implement the [OpenTracing APIs](https://opentracing.io). Agents should align implementations according to https://github.com/elastic/apm/issues/32.

### Distributed Tracing

See [`distributed-tracing.md`](distributed-tracing.md).

## Error/exception tracking

The agent support reporting exceptions/errors. Errors may come in one of two forms:

 - unhandled (or handled and explicitly reported) exceptions/errors
 - log records

Agents should include exception handling in the instrumentation they provide, such that exceptions are reported to the APM Server automatically, without intervention. In addition, hooks into logging libraries may be provided such that logged errors are also sent to the APM Server.

Errors may or may not occur within the context of a transaction or span. If they do, then they will be associated with them by recording the trace ID and transaction or span ID. This enables the APM UI to annotate traces with errors.

## Metrics

Agents periodically collect and report various metrics, described below.

### System/process CPU/Heap

All agents (excluding JavaScript RUM) should record the following basic system/process metrics:

 - `system.cpu.total.norm.pct`: system CPU usage since the last report, in the range `[0,1]` (0-100%)
 - `system.process.cpu.total.norm.pct`: process CPU usage since the last report, in the range `[0,1]` (0-100%)
 - `system.memory.total`: total usable (but not necessarily available) memory on the system, in bytes
 - `system.memory.actual.free`: total available memory on the system, in bytes
 - `system.process.memory.size`: process virtual memory size, in bytes
 - `system.process.memory.rss.bytes`: process resident set size, in bytes
 
### cgroup metrics

Where applicable, all agents (excluding JavaScript RUM) should record the following cgroup metrics:

 - `system.process.cgroup.memory.mem.limit.bytes`
 - `system.process.cgroup.memory.mem.usage.bytes`
 - `system.process.cgroup.memory.stats.inactive_file.bytes`

#### Metrics source

##### [cgroup-v1](https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt)
   - `system.process.cgroup.memory.mem.limit.bytes` - based on the `memory.limit_in_bytes` file
   - `system.process.cgroup.memory.mem.usage.bytes` - based on the `memory.usage_in_bytes` file
   - `system.process.cgroup.memory.stats.inactive_file.bytes` - based on the `total_inactive_file` line in the `memory.stat` file

##### [cgroup-v2](https://www.kernel.org/doc/Documentation/cgroup-v2.txt)
   - `system.process.cgroup.memory.mem.limit.bytes` - based on the `memory.max` file
   - `system.process.cgroup.memory.mem.usage.bytes` - based on the `memory.current` file
   - `system.process.cgroup.memory.stats.inactive_file.bytes` - based on the `inactive_file` line in the `memory.stat` file

#### Discovery of the memory files

All files mentioned above are located at the same directory. Ideally, we can discover this dir by parsing the `/proc/self/mountinfo` file, looking for the memory mount line and extracting the path from within it. An example of such line is: 
```
436 431 0:33 /docker/5042cfbb4ab36fcef9ca5f1eda54f40265c6ef3fe0694dfe34b9b474e70f8df5 /sys/fs/cgroup/memory ro,nosuid,nodev,noexec,relatime master:22 - cgroup memory rw,memory
```
The regex `^\d+? \d+? .+? .+? (.*?) .*cgroup.*memory.*` works in the cgroup-v1 systems tested so far, where the first and only group should be the directory path. However, it will probably take a few iterations and tests on different container runtimes and OSs to get it right. 
There is no regex currently suggested for cgroup-v2. Look in other agent PRs to get ideas.

Whenever agents fail to discover the memory mount path, they should default to `/sys/fs/cgroup/memory`.

#### Special values for unlimited memory quota

Special values are used to indicate that the cgroup is not configured with a memory limit. In cgroup v1, this value is numeric - `0x7ffffffffffff000` and in cgroup v2 it is represented by the string `max`. 
Agents should not send the `system.process.cgroup.memory.mem.limit.bytes` metric whenever these special values are set.

### Runtime

Agent should record runtime-specific metrics, such as garbage collection pauses. Due to their runtime-specific nature, these will differ for each agent.

When capturing runtime metrics, keep in mind the end use-case: how will they be used? Is the format in which they are recorded appropriate for visualisation in Kibana? Do not record metrics just because it is easy; record them because they are useful.

### Transaction and span breakdown

Agents should record "breakdown metrics", which is a summarisation of how much time is spent per span type/subtype in each transaction group. This is described in detail in the [Breakdown Graphs](https://docs.google.com/document/d/1-_LuC9zhmva0VvLgtI0KcHuLzNztPHbcM0ZdlcPUl64#heading=h.ondan294nbpt) document, so we do not repeat it here.

## Logging Correlation

Agents should provide instrumentation/hooks for popular logging libraries in order to decorate structured log records with trace context. In particular, logging that occurs within the context of a transaction should add the fields `trace.id` and `transaction.id`; logging that occurs within a span should add the fields `trace.id`, `span.id`, and optionally `transaction.id`.

By adding trace context to log records, users will be able to move between the APM UI and Logs UI.

## Agent Configuration

Even though the agents should _just work_ with as little configuration and setup as possible we provide a wealth of ways to configure them to users' needs.

Generally we try to make these the same for every agent. Some agents might differ in nature like the JavaScript RUM agent but mostly these should fit. Still, languages are different so some of them might not make sense for your particular agent. That's ok!

Here's a list of the config options across all agents, their types, default values etc. Please align with these whenever possible:

- [APM Backend Agent Config Comparison](https://docs.google.com/spreadsheets/d/1JJjZotapacA3FkHc2sv_0wiChILi3uKnkwLTjtBmxwU/edit)

They are provided as environment variables but depending on the language there might be several feasible ways to let the user tweak them. For example besides the environment variable `ELASTIC_APM_SERVER_URL`, the Node.js Agent might also allow the user to configure the server URL via a config option named `serverUrl`, while the Python Agent might also allow the user to configure it via a config option named `server_url`.

### APM Agent Configuration via Kibana

Also known as "central configuration". Agents can query the APM Server for configuration updates; the server proxies and caches requests to Kibana.

Agents should poll the APM Server for config periodically by sending an HTTP request to the `/config/v1/agents` endpoint. Agents must specify their service name, and optionally environment. The server will use these to filter the configuration down to the relevant service and environment. There are two methods for sending these parameters:

1. Using the `GET` method, pass them as query parameters: `http://localhost:8200/config/v1/agents?service.name=opbeans&service.environment=production`
2. Using the `POST` method, encode the parameters as a JSON object in the body, e.g. `{"service": {"name": "opbeans", "environment": "production"}}`

The server will respond with a JSON object, where each key maps a config attribute to a string value. The string value should be interpreted the same as if it were passed in via an environment variable. Upon receiving these config changes, the agent will update its configuration dynamically, overriding any config previously specified. That is, config via Kibana takes highest precedence.

To minimise the amount of work required by users, agents should aim to enable this feature by default. This excludes RUM, where there is a performance penalty.

#### Interaction with local config

When an instrumented application starts, the agent should first load locally-defined configuration via environment variables, config files, etc. Once this has completed, the agent will begin asynchronously polling the server for configuration. Once available, this configuration will override the locally-defined configuration. This means that there will be a short time window at application startup in which locally-defined configuration will apply.

If a user defines and then later deletes configuration via Kibana, the agent should ideally fall back to the locally-defined configuration. As an example of how to achieve this: the Java agent defines a hierarchy of configuration sources, with configuration via Kibana having the highest precedence. When configuration is not available at one level, the agent obtains it via the next highest level, and so on.

#### Caching

As mentioned above, the server will cache config for each unique `service.name`, `service.environment` pair. The server will respond to config requests with two related response headers: [Etag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) and [Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control).

Agents should keep a record of the `Etag` value returned by the most recent successful config request, and then present it to future requests via the [If-None-Match](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-None-Match) header. If the config has not changed, the server will respond with 304 (Not Modified).

The `Cache-Control` header should contain a `max-age` directive, specifying the amount of time (in seconds) the response should be considered "fresh". Agents should use this to decide how long to wait before requesting config again. The server will respond with a `Cache-Control` header even if the request fails.

#### Dealing with errors

Agents must deal with various error scenarios, including:

 - 7.3 servers where the Kibana connection is not enabled (server responds with 403)
 - 7.3 servers where the Kibana connection is enabled, but unavailable (server responds with 503)
 - pre-7.3 servers that don't support the config endpoint (server responds with 404)
 - any other error (server responds with 5xx)

If the server responds with any 5xx, agents should log at error level. If the server responds with 4xx, agents are not required to log the response, but may choose to log it at debug level; either the central config feature is not available, or is not enabled. In either case, there is no expectation that the agent should take any action, so logging is not necessary.

In any case, a 7.3+ server _should_ respond with a Cache-Control header, as described in the section above, and agents should retry after the specified interval. For older servers, or for whatever reason a 7.3+ server does not respond with that header (or it is invalid), agents should retry after 5 minutes. We include this behaviour for older servers so that the agent will start polling after server upgrade without restarting the application.

If the agent does not recognise a config attribute, or does not support dynamically updating it, then it should log a warning such as:

```
Central config failure. Unsupported config names: unknown_option, disable_metrics, capture_headers
```

Note that in the initial implementation of this feature, not all config attributes will be supported by the APM UI or APM Server. Agents may choose to support only the attributes supported by the UI/server, or they may choose to accept additional attributes. The latter will enable them to work without change once additional config attributes are supported by the UI/server.

If the agent receives a known but invalid config attribute, it should log a warning such as:

```
Central config failure. Invalid value for transactionSampleRate: 1.2 (out of range [0,1.0])
```

Failure to process one config attribute should not affect processing of others.

#### Feature flag

Agents should implement a [configuration option](https://docs.google.com/spreadsheets/d/1JJjZotapacA3FkHc2sv_0wiChILi3uKnkwLTjtBmxwU), (`CENTRAL_CONFIG`) which lets users disable the central configuration polling.
