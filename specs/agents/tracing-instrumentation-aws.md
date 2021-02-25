## AWS services spans

We describe how to instrument some of AWS' services in this document.
Some of the services can use existing specs. When there are differences or additions, they have been noted below.

### S3 (Simple Storage Service)

AWS Simple Storage Service offers object storage via a REST API. The objects are organized into buckets, which are 
themselves organized into regions.

- `span.name`: The span name should follow this pattern: `S3 <OperationName> <bucket-name>`. For example,
`S3 GetObject my-bucket`. Note that the operation name is in CamelCase.
- `span.type`: `storage`
- `span.subtype`: `s3`
- `span.action`: The operation name in CamelCase. For example ‘GetObject’.

#### Span context fields

- **`context.destination.address`**: optional. Not available in some cases. Only set if the actual connection is available.
- **`context.destination.port`**: optional. Not available in some cases. Only set if the actual connection is available.
- **`context.destination.region`**: mandatory. The AWS region where the bucket is.
- **`context.destination.service.name`**: mandatory. Use `s3`
- **`context.destination.service.resource`**: optional. The bucket name, if available. The s3 API allows either the
bucket name or an Access Point to be provided when referring to a bucket. When an Access Point is provided, the access
point name preceded by `accesspoint/` should be extracted. For example, given an Access Point such as
`arn:aws:s3:us-west-2:123456789012:accesspoint/myendpoint`, the agent extracts `accesspoint/myendpoint`.
- **`context.destination.service.type`**: mandatory. Use `storage`.

### DynamoDB

AWS DynamoDB is a document database so instrumenting it will follow the [db spec](tracing-instrumentation-db.md). 
Note that the `db.instance` field is the AWS region.

The following field should also be set for DynamoDB:
- **`context.destination.region`**: mandatory. The AWS region where the table is, if available.

### SQS (Simple Queue Service)

AWS Simple Queue Service is a message queuing service. The [messaging spec](tracing-instrumentation-messaging.md) can 
be used for instrumenting SQS, but the follow specifications supersede those of the messaging spec.

- **`context.destination.region`**: mandatory. The AWS region where the queue is.

For distributed tracing, the SQS API has "message attributes" that can be used in lieu of headers.

### SNS (AWS Simple Notification Service)

The AWS Simple Notification Service can be instrumented using the [messaging spec](tracing-instrumentation-messaging.md), 
but the only action that is instrumented is `PUBLISH`. These specifications supersede those of the messaging spec: 

- `span.name`: The span name should follow this pattern: `SNS PUBLISH <TOPIC-NAME>`. For example,
`SNS PUBLISH MyTopic`.
- **`context.destination.region`**: mandatory. The AWS region where the topic is.

For distributed tracing, the SNS API has "message attributes" that can be used in lieu of headers.
