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
but the only action that is instrumented is [Publish](https://docs.aws.amazon.com/sns/latest/api/API_Publish.html). These specifications supersede those of the messaging spec:

- `span.name`:
    - For a publish action including a `TopicArn`, the span name MUST be `SNS PUBLISH to <topic-name>`. For example, for a TopicArn of `arn:aws:sns:us-east-2:123456789012:My-Topic` the topic-name is `My-Topic`. (Implementation note: this can extracted with the equivalent of this Python expression: `topicArn.split(':').pop()`.)
    - For a publish action including a `TargetArn` (an endpoint ARN created via [CreatePlatformEndpoint](https://docs.aws.amazon.com/sns/latest/api/API_CreatePlatformEndpoint.html)), the span name MUST be `SNS PUBLISH to <application-name>`. For example, for a TargetArn of `arn:aws:sns:us-west-2:123456789012:endpoint/GCM/gcmpushapp/5e3e9847-3183-3f18-a7e8-671c3a57d4b3` the application-name is `endpoint/GCM/gcmpushapp`. The endpoint UUID represents a device and mobile app. For manageable cardinality, the UUID must be excluded from the span name. (Implementation note: this can be extracted with the equivalent of this Python expression: `targetArn.split(':').pop().rsplit('/', 1)[0]`)
    - For a publish action including a `PhoneNumber`, the span name MUST be `SNS PUBLISH to [PHONENUMBER]`. The actual phone number MUST NOT be included because it is [PII](https://en.wikipedia.org/wiki/Personal_data) and cardinality is too high. 
- `span.action`: 'publish'

- **`context.destination.cloud.region`**: mandatory. The AWS region where the topic is.

For distributed tracing, the SNS API has "message attributes" that can be used in lieu of headers.
