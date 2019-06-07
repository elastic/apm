# Building an agent

So you want to build an agent for Elastic APM? That's great, here's what you need to know.

**Note:** This document is never done.
If you come across something weird or something missing, please add it or tell someone else to do so.

**✨ Always Be Improving Documentation ✨**

---

<!-- toc -->

- [Introduction](#introduction)
- [Features to implement](#features-to-implement)
  * [Transactions](#transactions)
    + [`result` and status codes](#result-and-status-codes)
    + [Transaction sampling](#transaction-sampling)
  * [Spans](#spans)
    + [Span limit per transaction](#span-limit-per-transaction)
    + [Databases and data stores](#databases-and-data-stores)
      + [Database Types](#database-types)
  * [Manual APIs](#manual-apis)
  * [Batching of collected data](#batching-of-collected-data)
  * [Compression](#compression)
  * [Agent name](#agent-name)
- [Agent configuration](#agent-configuration)

<!-- tocstop -->

## Introduction

1. Read our [Getting started with APM](https://www.elastic.co/guide/en/apm/get-started/current/overview.html) overview to understand the big picture architecture.
    Your agent will be talking to the APM Server using HTTP.
    The server exposes a simple API that accepts data as JSON (called the intake API)

1. There are two separate categories of data you should capture and send from your agent to the APM Server:

    - Tracing related data. See the [Transactions API](https://www.elastic.co/guide/en/apm/server/current/transaction-api.html)
    - Error/exception releated data. See the [Errors API](https://www.elastic.co/guide/en/apm/server/current/error-api.html)

    APM Server converts these into documents in Elasticsearch and APM in Kibana let's you see graphs as well as dig into the data in an interactive way.
    Read more about these Elasticsearch documents in the [APM Server Event Types](https://www.elastic.co/guide/en/apm/server/current/event-types.html) documentation.
    
1. Agents try to be as good citizens as possible in the programming language they are written for.
Even though every langauge ends up reporting to the same server API with the same JSON format, the agents should try to make as much sense in the context of the relevant language as possible.
We want to both streamline the agents to work the same in every context **but** also make them feel like they were built specifically for each language.
It's up to you to figure out how this looks in the language you are writing your agent for.

## Features to implement

The agents try to be as easily set up as possible.
The fewer setup steps the better.
This means agents typically know the two or three most popular frameworks or libraries of the relevant language and how to interact with them.

The agents also provide APIs for manual use.
This lets developers add their own Transactions or add information to the already instrumented ones.

### Transactions

#### HTTP Transactions

The agent should automatically start an new transaction when an incoming HTTP request to the instrumented application is detected.
When the incoming request ends, the transaction should be ended automatically as well.

The `type` of this transaction should be `request`.

The transaction should have a describing `name`.
A typical transaction name for an incoming HTTP request might be named after the route, e.g. `GET /users/{id}`.
It could also be named after the controller action e.g. `UsersController#index`.
It's up to you to pick a scheme that's the most _natural_ for the language or web framework you are instrumenting.

In case a name cannot be automatically determined,
and a custom name hasn't been provided by other means,
the transaction should be named `<METHOD> unknown route`,
e.g. `POST unknown route`.
This would normally also apply to requests to unknown endpoints,
e.g. the transaction for the request `GET /this/path/does/not/exist` would be named `GET unknown route`,
whereas the transaction for the request `GET /users/123` would still be named `GET /users/{id}` even if the id `123` didn't match any known user and the request resulted in a 404.

#### Associated spans

Transactions have many _spans_.
These represent bits of work happening during the _transaction_.
This is typically things like rendering templates or querying a database.
The agent should also have a sense of the most common libraries for these and instrument them without any further setup from the app developers.

#### `result` and status codes

For web request transactions set the `result` to `HTTP` plus an abbreviated HTTP status code -- like `HTTP 2xx` or `HTTP 4xx`.
That way they get grouped and shaded in the RPM graphs.
The precise status codes can still be found in `transaction.context.response.status_code`.

#### Transaction sampling

A _sampled_ transaction includes `spans` and `context`.
This is the default for all transactions but as many transactions typically will be the same, the agents can skip adding `spans` and `context` to a fraction of the transactions.
This is called _sampling_.

This saves some work and shrinks the payload sizes while still providing the same information in the APM UI.

Agents currently implement randomized sampling based of a sample rate between 1.0 and 0.0.
1.0 meaning every transaction is sampled and has all the info and 0.5 meaning a random selection of around half of transactions skip the extra work.

If a transaction is not sampled, you should set the `sampled: false` property and omit collecting `spans` and `context`.

### Spans

_Spans_ are bits of work that happen during _transactions_.

#### Span limit per transaction

To handle edge cases where a single transaction accumulates a lot of spans, the agent should allow the user to start dropping spans when the associated transaction exeeds a configurable number of spans.

When a span is dropped, it's not included in the `spans` array on the transaction object.
Instead a dropped-span counter is incremented:

```json
"span_count": {
  "dropped": {
    "total": 42
  }
}
```

Here's how the limit can be configured for [Node.js](https://www.elastic.co/guide/en/apm/agent/nodejs/current/agent-api.html#transaction-max-spans) and [Python](https://www.elastic.co/guide/en/apm/agent/python/current/configuration.html#config-transaction-max-spans).

#### Databases and data stores

It's a nice experience to have the exact queries for each span in the transaction overview.
Makes it easier to tell them from each other.
But be aware that queries may contain confidential information.
Depending on the kind of database, you could strip search values.
`SELECT * FROM users WHERE name = %` provides a lot of information without mentioning the user's name.
If the query was `SELECT * FROM users WHERE password = 'super_secret'` we'd end up storing everyone's passwords.

Key-value stores like Redis or document stores like MongoDB might be harder to parse.
When in doubt collect less.
Redis commands can be kept to just `GET` or `LRANGE` and still provide enough info to tell the story.

##### Database Types

The following `context.db.type` values have been standardized:

| Database      | `context.db.type` |
|---------------|-------------------|
| MySQL         | `sql`             |
| MariaDB       | `sql`             |
| PostgreSQL    | `sql`             |
| MSSQL         | `sql`             |
| Redis         | `redis`           |
| Memcached     | `memcached`       |
| Hazelcast     | `hazelcast`       |
| MongoDB       | `mongo`           |
| HBase         | `hbase`           |
| Elasticsearch | `elasticsearch`   |
| Cassandra     | `cassandra`       |
| Neo4j         | `neo4j`           |
| H2            | `h2`              |

### Manual APIs

All agents let users create and manage transactions and spans manually.
Here's how that works in the Node.js agent:

- [Node.js agent Transaction API](https://www.elastic.co/guide/en/apm/agent/nodejs/current/transaction-api.html)
- [Node.js agent Span API](https://www.elastic.co/guide/en/apm/agent/nodejs/current/span-api.html)

### Batching of collected data

Both the transaction and error endpoints support batching.

Transaction payloads should be batched and sent in bundles in an interval.
This should happen in the least obtrusive way for the running application e.g. in another thread or however it's feasible in the relevant language.

Error payloads typically get sent immediately, also in an as non-blocking manner as possible.

For details see the Python config options [flush_interval](https://www.elastic.co/guide/en/apm/agent/python/current/configuration.html#config-flush-interval) and [max_queue_size](https://www.elastic.co/guide/en/apm/agent/python/current/configuration.html#config-max-queue-size).

### Compression

The APM Server accepts both uncompressed and compressed HTTP requests.
Agents should compress the HTTP payload by default.

Set the `Content-Encoding` HTTP header if compressing the payload.
The following compression formats are supported:

- zlib data format (`Content-Encoding: deflate`)
- gzip data format (`Content-Encoding: gzip`)

### Agent name

The payload also contains meta information about the agent which collected the data under `Payload.service.agent`.
The agent name of the official agents should just be the name of the language the agent is written for,
in lower case,
e.g. `python`.

## Agent configuration

Even though the agents should _just work_ with as little configuration and setup as possible we provide a wealth of ways to configure them to users' needs.

Generally we try to make these the same for every agent.
Some agents might differ in nature like the JavaScript RUM agent but mostly these should fit.
Still,
languages are different so some of them might not make sense for your particular agent.
That's ok!

Here's a list of the config options across all agents, their types, default values etc.
Please align with these whenever possible:

- [APM Backend Agent Config Comparison](https://docs.google.com/spreadsheets/d/1JJjZotapacA3FkHc2sv_0wiChILi3uKnkwLTjtBmxwU/edit)

They are provided as environment variables but depending on the language there might be several feasible ways to let the user tweak them.
For example,
besides the environment variable `ELASTIC_APM_SERVER_URL`,
the Node.js Agent might also allow the user to configure the server URL via a config option named `serverUrl`,
while the Python Agent might also allow the user to configure it via a config option named `server_url`.
