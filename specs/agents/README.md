# Building an agent

So you want to build an agent for Elastic APM? That's great, here's what you need to know.

**Note:** This is a living document.
If you come across something weird or find something missing, please add it or ask open an issue.

---

# Introduction

The [Getting started with APM](https://www.elastic.co/guide/en/observability/current/apm.html) provides an overview to understand the big picture architecture.

Your agent will be talking to the APM Server using HTTP, sending data to it as JSON or ND-JSON. There are multiple categories of data that each agent captures and sends to the APM Server:

  - Trace data: transactions and spans (distributed tracing)
  - Errors/exceptions (i.e. for error tracking)
  - Metrics (host process-level metrics, and language/runtime-specific metrics)

You can find details about each of these in the [APM Data Model](https://www.elastic.co/guide/en/observability/current/apm-data-model.html) documentation. The [Intake API](https://www.elastic.co/guide/en/observability/current/apm-api-events.html) documentation describes the wire format expected by APM Server. APM Server converts the data into Elasticsearch documents, and then the APM UI in Kibana provides visualisations over that data, as well as enabling you to dig into the data in an interactive way.

# Guiding Philosophy

1. Agents try to be as good citizens as possible in the programming language they are written for. Even though every language ends up reporting to the same server API with the same JSON format, the agents should try to make as much sense in the context of the relevant language as possible. We want to both streamline the agents to work the same in every context **but** also make them feel like they were built specifically for each language. It's up to you to figure out how this looks in the language you are writing your agent for.

2. Agents should be as close to zero configuration as possible.

  - Use sensible defaults, aligning across agents unless there is a compelling reason to have a language-specific default.
  - Agents should typically come with out-of-the-box instrumentation for the most popular frameworks or libraries of their relevant language.
  - Users should be able to disable specific instrumentation modules to reduce overhead, or where details are not interesting to them.

3. The overhead of agents must be kept to a minimum, and must not affect application behaviour.


# Features to implement

- [Transport](transport.md)
- [Metadata](metadata.md)
- Tracing
  - [Transactions](tracing-transactions.md)
    - [Transaction Grouping](tracing-transaction-grouping.md)
  - [Spans](tracing-spans.md)
  - [Span destination](tracing-spans-destination.md)
  - [Handling huge traces](handling-huge-traces/)
    - [Hard limit on number of spans to collect](handling-huge-traces/tracing-spans-limit.md)
    - [Collecting statistics about dropped spans](handling-huge-traces/tracing-spans-dropped-stats.md)
    - [Dropping fast exit spans](handling-huge-traces/tracing-spans-drop-fast-exit.md)
    - [Compressing spans](handling-huge-traces/tracing-spans-compress.md)
  - [Sampling](tracing-sampling.md)
  - [Distributed tracing](tracing-distributed-tracing.md)
  - [Tracer API](tracing-api.md)
  - Instrumentation
      - [AWS](tracing-instrumentation-aws.md)
      - [Databases](tracing-instrumentation-db.md)
      - [HTTP](tracing-instrumentation-http.md)
      - [Messaging systems](tracing-instrumentation-messaging.md)
      - [gRPC](tracing-instrumentation-grpc.md)
      - [GraphQL](tracing-instrumentation-graphql.md)
      - [OpenTelemetry API Bridge](tracing-api-otel.md)
- [Error/exception tracking](error-tracking.md)
- [Metrics](metrics.md)
- [Logging Correlation](log-correlation.md)
- [Agent Configuration](configuration.md)
- [Agent logging](logging.md)
- [Data sanitization](sanitization.md)
- [Field limits](field-limits.md)

# Processes

- [Proposing changes to the specification](../../.github/pull_request_template.md)
- [Proposing new fields to the intake API](process-new-fields.md)
