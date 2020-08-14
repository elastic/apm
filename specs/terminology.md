# Terminology

This document describes terms and concepts often used within the APM ecosystem.

#### APM
Application Performance Monitoring is the concept of profiling and monitoring services and applications. For instance, it accounts for things like requests per second, but not how much free space is on a disk.

#### Distributed Tracing
Distributed tracing makes it possible to analyze performance throughout a microservice architecture all in one view. This is accomplished by tracing all of the requests - from the initial web request in the front-end service - to queries made through multiple back-end services. [Further reading](https://www.elastic.co/guide/en/apm/get-started/current/distributed-tracing.html)

#### Instrumentation
To be able to monitor an application it needs to be _instrumented_ by an APM Agent. 
Usually not everything is instrumented because that would incur a very large overhead. We are interested only in performance-sensitive activities, like database queries or web requests. Instrumentation can happen automatically (the Elastic APM Agents instrument many frameworks and databases automatically), or manually with a programmatic API.

#### Library frames vs App frames

 > A **stack frame** is a frame of data that gets pushed onto the stack. In the case of a call stack, a stack frame would represent a function call and its argument data ([Source](https://stackoverflow.com/a/10057535/434980))

We distinguish between the user's own code, and the code of the user's dependencies. Often the user is more interested in stack frames from their own code, so these are highlighted.
[Further reading](https://www.elastic.co/guide/en/apm/agent/nodejs/master/performance-tuning.html#performance-source-lines)

#### Real User Monitoring (RUM)
Real User Monitoring (RUM) tries to capture the real user’s experience with the application. Generally this means monitoring the application on the user’s machine e.g. their browsers or mobile devices. The APM agent used in the browser is called [RUM agent](https://www.elastic.co/guide/en/apm/agent/rum-js/4.x/intro.html)

#### Service
The application/service being instrumented by APM. A service is uniquely identified by name + environment.

#### Time to glass
The time from an event occurs in an application until it is visible to the user in the APM UI

## Elastic APM Architecture

The Elastic APM offering consists of APM Agents, APM Server, APM UI and Kibana dashboards.

#### APM Agent 
An APM agent lives inside an application and will automatically collect APM data (transactions, spans, metrics and errors) and send it to the APM Server.
[Further reading](https://www.elastic.co/guide/en/apm/get-started/current/components.html#_apm_agents)

#### APM Server
The APM Server receives data from the Elastic APM agents and stores the data into Elasticsearch.
[Further reading](https://www.elastic.co/guide/en/apm/get-started/current/components.html#_apm_server)

#### APM UI
APM UI is a Kibana plugin which reads captured APM data from Elasticsearch, and displays it in curated charts and tables that allow the user to easily compare and debug their applications. This UI is only available with an Elastic Basic License.
[Further reading](https://www.elastic.co/guide/en/kibana/7.3/xpack-apm.html)

#### Kibana dashboards (aka APM dashboards)
Custom Kibana dashboards made for APM. These used to be bundled with Kibana but are now located in the [apm-contrib repo](https://github.com/elastic/apm-contrib/tree/471ef577fe6ae583d49ced4b2047a3763fac7a7b/kibana). The dashboards are available without an Elastic license.

## APM documents

#### Span
Spans contain information about a specific code path that has been executed. They measure from the start to end of an activity, and they can have a parent/child relationship with other spans.
[Further reading](https://www.elastic.co/guide/en/apm/get-started/current/transaction-spans.html)

#### Transaction
Transactions are a special kind of span that have additional attributes associated with them. They describe an event captured by an Elastic APM agent instrumenting a service. You can think of transactions as the highest level of work you’re measuring within a service
[Further reading](https://www.elastic.co/guide/en/apm/get-started/current/transactions.html)

#### Trace
A trace is a grouping of spans and transactions that all share the same `trace.id`

## Sampling

To reduce processing and storage overhead, transactions may be "sampled". Sampling limits the amount of data that is captured for transactions: non-sampled transactions will not record context, and related spans will not be captured.

#### Adaptive sampling
TODO

#### Head based sampling
Deciding whether to sample a trace before it has started. The decision to sample will often be very simplistic e.g. sample 1% of traces.

#### Tail-based sampling
Deciding whether to sample a trace after it has ended. This makes it possible to sample based on _interesting_ events like error occurrence, latency etc.

