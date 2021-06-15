## AWS services spans

We describe how to instrument some of AWS' services in this document.
Some of the services can use existing specs. When there are differences or additions, they have been noted below.

### S3 (Simple Storage Service)

AWS Simple Storage Service offers object storage via a REST API. The objects are organized into buckets, which are
themselves organized into regions.

Field semantics and values for S3 are defined in the [S3 table within the database spec](tracing-instrumentation-db.md#aws-s3).

### DynamoDB

AWS DynamoDB is a document database so instrumenting it will follow the [db spec](tracing-instrumentation-db.md).
DynamoDB-specific specifications that supercede generic db field semantics are defined in the [DynamoDB table within the database spec](tracing-instrumentation-db.md#aws-dynamodb).

### SQS (Simple Queue Service)

AWS Simple Queue Service is a message queuing service. The [messaging spec](tracing-instrumentation-messaging.md) can
be used for instrumenting SQS, but the follow specifications supersede those of the messaging spec.

- **`context.destination.cloud.region`**: mandatory. The AWS region where the queue is.

#### Distributed Tracing

For distributed tracing, the SQS API has "message attributes" that can be used in lieu of headers.

Agents should use an attribute name of `traceparent` when sending the trace parent header value via the SQS message attributes.  Agents should use an attribute name of `tracestate` if sending trace state header value in an SQS message attribute.  Agents should not prefix these names with an `elastic-` namespace.

SQS has a documented limit of ten message attributes per message.  Agents _should not_ add `traceparent` or `tracestate` headers to the message attributes if adding those fields would put an individual message over this limit.  Agents _should_ log a message if they omit either `traceparent` or `tracestate` due to these length limits. 

### SNS (AWS Simple Notification Service)

The AWS Simple Notification Service can be instrumented using the [messaging spec](tracing-instrumentation-messaging.md),
but the only action that is instrumented is `PUBLISH`. These specifications supersede those of the messaging spec:

- `span.name`: The span name should follow this pattern: `SNS PUBLISH <TOPIC-NAME>`. For example,
`SNS PUBLISH MyTopic`.

- **`context.destination.cloud.region`**: mandatory. The AWS region where the topic is.

For distributed tracing, the SNS API has "message attributes" that can be used in lieu of headers.
