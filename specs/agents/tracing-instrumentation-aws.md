## AWS services spans

We describe how to instrument some of AWS' services in this document.
Many of the services have a fairly small API beyond the basic administrative commands. We therefore
only instrument the most interesting and often-repeated operations.

### S3 (Simple Storage Service)

AWS Simple Storage Service offers object storage via a REST API. The objects are organized into buckets, which are 
themselves organized into regions.

- `span.name`: The span name should follow this pattern: `S3 <OPERATION_NAME> <BUCKET-NAME>`. For example,
`S3 GET_OBJECT myBucket`. Note that the operation name is in all caps with underscores (snake case in caps).
- `span.type`: `storage`
- `span.subtype`: `s3`
- `span.action`: The operation name in snake case in lower case. For example ‘get_object’. 

#### Span context fields

- **`context.destination.address`**: optional. Not available in some cases. Only set if the actual connection is available.
- **`context.destination.port`**: optional. Not available in some cases. Only set if the actual connection is available.
- **`context.destination.region`**: mandatory. The AWS region where the bucket is.
- **`context.destination.service.name`**: mandatory. Use `s3`
- **`context.destination.service.resource`**: mandatory. The bucket ARN, if available, otherwise simply `s3/<BUCKET-NAME`.
Note that the ARN will contain the bucket name. The s3 API allows either the bucket name or the ARN to be provided when
referring to a bucket so use whichever the user has provided.
- **`context.destination.service.type`**: mandatory. Use `storage`.

### DynamoDB

AWS DynamoDB is a document database so instrumenting it will follow the [db spec](tracing-instrumentation-db.md). 
Note that the `db.instance` field is 
the AWS region.

### SQS (Simple Queue Service )

AWS Simple Queue Service is a message queuing service. The [messaging spec](tracing-instrumentation-messaging.md) can 
be used for instrumenting SQS, but the follow specifications supersede those of the messaging spec.

- **`context.message.queue.name`**: mandatory. `sqs/<QUEUE-NAME>`. For example, `sqs/MyQueue` 
- **`context.destination.region`**: mandatory. The AWS region where the queue is.
- **`context.destination.service.resource`**: mandatory. The queue url, which is required for all queue operations.

### SNS (AWS Simple Notification Service)

The AWS Simple Notification Service can be instrumented using the [messaging spec](tracing-instrumentation-messaging.md), 
but the only action that is instrumented is `PUBLISH`. These specifications supersede those of the messaging spec: 

- `span.name`: The span name should follow this pattern: `SNS PUBLISH <TOPIC-NAME>`. For example,
`SNS PUBISH MyTopic`.
- **`context.message.queue.name`**: mandatory. `sns/<TOPIC-NAME>`. For example, `sns/MyTopic`
- **`context.destination.region`**: mandatory. The AWS region where the topic is.
- **`context.destination.service.resource`**: mandatory. The topic ARN.