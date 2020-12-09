## Messaging Systems

The instrumentation of messaging systems includes:
- Transaction creation on message reception, either as a child of the message-sending span, if the sending action is traced (meaning 
distributed tracing support), or as root
- Span creation for message sending action
- Span creation on message *polling that occurs within a traced transaction*

### Passive vs. active message reception

Message send/publish events can only be captured as spans if occurring within a traced transaction.
Message consumption can be divided into two types: passive, where you would implement a listener that is called once a message is available, 
and active, where the queue/topic is being polled (blocking or non-blocking). 

Passive consumption typically results in a `messaging` transaction and is pretty straightforward to trace - start at entry and end at exit. 

Message polling can be done within a traced transaction, in which case it should result in a messaging span, or it can be the initiating 
event for a message handling flow. Capturing polling spans is also mostly straightforward. 
For polling-based transactions, our goal is to capture the message handling flow, which typically *starts after the polling action exits*, 
returning a message. This may be tricky if the handling flow is not implemented within a well defined API. Use other agent implementation
as reference.
The agent should not create a transaction based on polling APIs if the polling action did not result with a message (as opposed to 
polling spans, where we want to capture such as well).

### Typing

- Transactions: 
  - `transaction.type`: `messaging`
- Spans: 
  - `span.type`: `messaging` 
  - `span.subtype`: the name of the framework - e.g. `jms`, `kafka`, `rabbitmq` 
  - `span.action`: `send` or `receive`
  
### Naming

Transaction and span names may* follow this pattern: `<MSG-FRAMEWORK> SEND/RECEIVE/POLL to/from <QUEUE-NAME>`.
Examples:
- `JMS SEND to MyQueue`
- `RabbitMQ RECEIVE from MyQueue`**
- `RabbitMQ POLL from MyExchange`**

Agents may deviate from this pattern, as long as they ensure a proper cardinality is maintained, that is- neither too low nor too high. 
For example, agents may choose to name all transactions/spans reading-from/sending-to temporary queues equally. 
On the other end, agents may choose to append a cardinality-increasing factor to the name, like the routing key in RabbitMQ.

\* Java agent's instrumentation for Kafka does not follow this pattern at the moment.

#### \** RabbitMQ naming specifics 

In RabbitMQ, queues are only relevant in the receiver side, so the exchange name is used instead for sender spans.
When the default exchange is used (denoted with an empty string), it should be replaced with `<default>`. 

Agents may add an opt-in config to append the routing key to the name as well, for example: `RabbitMQ RECEIVE from MyExchange\58D7EA987`.

For RabbitMQ transaction and polling spans, the queue name is used instead, whenever available (i.e. when the polling yields a message).

### Context fields

- **`context.message.queue.name`**: optional for `messaging` spans and transactions. Indexed as keyword. Wherever the broker terminology 
uses "topic", this field will contain the topic name. In RabbitMQ, whenever the queue name is not available, use exchange name instead.
- **`context.message.age.ms`**: optional for message/record receivers only (transactions or spans). 
A numeric field indicating the message's age in milliseconds. Relevant for transactions and 
`receive` spans that receive valid messages. There is no accurate definition as to how this is calculated. If the messaging framework 
provides a timestamp for the message- agents may use it. Otherwise, the sending agent can add a timestamp _indicated as milliseconds since 
epoch UTC_ to the message's metadata to be retrieved by the receiving agent. If a timestamp is not available- agents should omit this field. 
Clock skews between agents are ignored, unless the calculated age (receive-timestamp minus send-timestamp) is negative, in which case the 
agent should report 0 for this field.
- **`context.message.routing-key`**: optional. Use only where relevant. Currently only RabbitMQ.

#### Transaction context fields

- **`context.message.body`**: similar to HTTP requests' `context.request.body`- only fill in messaging-related **transactions** (ie 
incoming messages creating a transaction) and not for outgoing messaging spans. 
   - Capture only when `ELASTIC_APM_CAPTURE_BODY` config is set to `true`.
   - Only capture UTF-8 encoded message bodies.
   - Limit size to 10000 characters. If longer than this size, trim to 9999 and append with ellipsis
- **`context.message.headers`**: similar to HTTP requests' `context.request.headers`- only fill in messaging-related **transactions**.
   - Capture only when `ELASTIC_APM_CAPTURE_HEADERS` config is set to `true`.
   - Sanitize headers with keys configured through `ELASTIC_APM_SANITIZE_FIELD_NAMES`.
   - Intake: key-value pairs, same like `context.request.headers`.

#### Span context fields

- **`context.destination.address`**: optional. Not available in some cases. Only set if the actual connection is available.
- **`context.destination.port`**: optional. Not available in some cases. Only set if the actual connection is available.
- **`context.destination.service.name`**: mandatory. Use the framework name in lowercase, e.g. `kafka`, `rabbitmq`.
- **`context.destination.service.resource`**: mandatory. Use the framework name in lowercase. Wherever the queue/topic/exchange name is
 available, append it with a leading `/`, for example: `kafka/myTopic`, `rabbitmq/myExchange`, `rabbitmq`.
- **`context.destination.service.type`**: mandatory. Use `messaging`.

### `ELASTIC_APM_IGNORE_MESSAGE_QUEUES` configuration

Used to filter out specific messaging queues/topics from being traced.

This property should be set to a list containing one or more strings. When set, sends-to and receives-from the specified 
queues/topic will be ignored.

|                |   |
|----------------|---|
| Type           | `List<`[`WildcardMatcher`](../../tests/agents/json-specs/wildcard_matcher_tests.json)`>` |
| Default        | empty |
| Dynamic        | `true` |
| Central config | `false` |
