# AWS Lambda instrumentation
This spec specifies the instrumentation of applications / services running on AWS Lambda.

An AWS Lambda application needs to implement a **handler method** that is called whenever that Lambda function is invoked. A handler method receives (at least) two objects with useful information:
- `event`: Depending on the trigger type of the Lambda function this object contains different, trigger-specific data. For some trigger types this object may be empty/null.
- `context`: This object provides generic (trigger agnostic) meta information about the Lambda function.

In our instrumentation we use these objects to derive useful meta and context information.

## Generic Lambda Instrumentation
In general, to instrument Lambda functions, we create transactions that wrap the execution of that handler method. In cases where we cannot assume any type or information in the `event` object (e.g. if the trigger type is undefined), we ignore trigger-specific information and simply wrap the handler method with a transaction, while using the `context` object to derive some necessary fields:

Field | Value | Description | Source
---   | ---   | --- | ---
`name` | e.g. `MyFunctionName` | The transaction name. Use function name if trigger type is `other`. | `context.functionName`
`type` | e.g. `request`, `messaging` | The transaction type. | Use `request` if trigger type is undefined.
`outcome` | `success` / `failure` | Set to `failure` if there was a [function error](https://docs.aws.amazon.com/lambda/latest/dg/invocation-retries.html). | -
`result` | `success` / `failure` / `HTTP Xxx` | See API Gateway below. For other triggers, set to `failure` if there was a function error, otherwise `success`. | Trigger specific.
`faas.id` | e.g. `arn:aws:lambda:us-west-2:123456789012:function:my-function` | Use the ARN of the function **without the alias suffix**. | `context.invokedFunctionArn`, remove the 8th ARN segment if the ARN contains an alias suffix. `arn:aws:lambda:us-west-2:123456789012:function:my-function:someAlias` will become `arn:aws:lambda:us-west-2:123456789012:function:my-function`.
`faas.trigger.type` | `other` | The trigger type. Use `other` if trigger type is unknown / cannot be specified. | More concrete triggers are `http`, `pubsub`, `datasource`, `timer` (see specific triggers below).
`faas.execution` | `af9aa4-a6...` | The AWS request ID of the function invocation | `context.awsRequestId`
`faas.coldstart` | `true` / `false` | Boolean value indicating whether a Lambda function invocation was a cold start or not. | [see section below](deriving-cold-starts)
`faas.trigger.request_id` | - | Do not set this field if trigger type is `other`.  | Trigger specific.
`context.cloud.origin.provider` | `aws` | Constant value for the origin cloud provider. | -
`context.cloud.origin.*` | - | Do not set these fields if trigger type is `other`.  | Trigger specific.
`context.service.origin.*` | - | Do not set these fields if trigger type is `other`. | Trigger specific.

Note that `faas.*` fields *are not* nested under the context property [in the intake api](https://github.com/elastic/apm-server/blob/master/docs/spec/v2/transaction.json)! `faas` is a top-level key on the transaction.

### Overwriting Metadata
Automatically capturing cloud metadata doesn't work reliably from a Lambda environment. Moreover, retrieving cloud metadata through an additional HTTP request may slowdown the lambda function / increase cold start behaviour. Therefore, the generic cloud metadata fetching should be disabled when the agent is running in a lambda context (for instance through checking for the existance of the `AWS_LAMBDA_FUNCTION_NAME` environment variable).
Where possible, metadata should be overwritten at Lambda runtime startup corresponding to the field specifications in this spec.

Some metadata fields are not available at startup (e.g. `invokedFunctionArn` which is needed for `service.id` and `cloud.region`). Therefore, retrieval of metadata fields in a lambda context needs to be delayed until the first execution of the lambda function, so that information provided in the `context` object can used to set metadata fields properly.

The following metadata fields are relevant for lambda functions:

Field | Value | Description | Source
---   | ---   | --- | ---
`service.name`| e.g. `MyFunctionName` | If the service name is *explicitly* specified through the `service_name` agent config option, use the configured name. Otherwise, use the name of the Lambda function. | If the service name is not explicitly configured, use the Lambda function name: `AWS_LAMBDA_FUNCTION_NAME` or `context.functionName`
`service.version` | e.g. `$LATEST` |  If the service version is *explicitly* specified through the `service_version` agent config option, use the configured version. Otherwise, use the lambda function version. | If the service version is not explicitly configured, use the Lambda function version: `AWS_LAMBDA_FUNCTION_VERSION` or `context.functionVersion`
`service.framework.name` | `AWS Lambda` | Constant value for the framework name. | -
`service.runtime.name`| e.g. `AWS_Lambda_java8` | The lambda runtime. | `AWS_EXECUTION_ENV`
`service.node.configured_name` | e.g. `2019/06/07/[$LATEST]e6f...` | The log stream name uniquely identifying a function instance. | `AWS_LAMBDA_LOG_STREAM_NAME` or `context.logStreamName`
`cloud.provider` | `aws` | Constant value for the cloud provider. | -
`cloud.region` | e.g. `us-east-1` | The cloud region. | `AWS_REGION`
`cloud.service.name` | `lambda` |  Constant value for the AWS service.
`cloud.account.id` | e.g. `123456789012` | The cloud account id of the lambda function. | 5th fragment in `context.invokedFunctionArn`.

### Deriving cold starts
A cold start occurs if AWS needs first to initialize the Lambda runtime (including the Lambda process, such as JVM, Node.js process, etc.) in order to handle a request. This happens for the first request and after long function idle times. A Lambda function instance only executes one event at a time (there is no concurrency). Thus, detecting a cold start is as simple as detecting whether the invocation of a __handler method__ is the **first since process startup** or not. This can be achieved with a global / process-scoped flag that is flipped at the first execution of the handler method.

### Disabled functionalities
The following agent functionalities need to be disabled when tracing AWS Lambda functions until decided otherwise:
- **Metrics collection:** this includes all kind of metrics: system, process and breakdown metrics and is equivalent to 
setting `ELASTIC_APM_METRICS_INTERVAL = 0`
- **Remote configuration:** equivalent to setting `ELASTIC_APM_CENTRAL_CONFIG = false`
- **Cloud metadata discovery:** equivalent to setting `ELASTIC_APM_CLOUD_PROVIDER = none`
- **System metadata discovery:** in some agents, this may be a relatively heavy task. For example, the Java agent 
executes extenal commands in order to discover the hostname, which is not required for AWS Lambda metadata. All other 
agents read and parse files to extract container and k8s metadata, which is not required as well.

There are two main approaches for agents to disable the above functionalities:
* Agents that will be always deployed as part of an additional APM Agent Lambda layer (e.g. Java agent) may disable this 
through configuration options (e.g. environment variables) built in the lambda wrapper script(`AWS_LAMBDA_EXEC_WRAPPER`) 
that is provided with the APM Agent Lambda layer.
* Agents that will be used with AWS lambda without the need for an additional Lambda layer must detect that they are 
running in an AWS Lambda environment (for instance through checking for the existance of the `AWS_LAMBDA_FUNCTION_NAME` 
environment variable). Such agents should disable the aforementioned functionalities programmatically to achieve the 
same behaviour that would be achieved through the corresponding configuration options.

## Trigger-specific Instrumentation
Lambda functions can be triggered in many different ways. A generic transaction for a Lambda invocation can be created independently of the actual trigger. However, depending on the trigger type, different information might be available that can be used to capture additional transaction data or that allows additional, valuable spans to be derived. The most common triggers that we want dedicated instrumentation support for are the following:

- API Gateway V1
- API Gateway V2
- SQS
- SNS
- S3

If none of the above apply, the fallback should be a generic instrumentation (as described above) that can deal with any type of trigger (thus capturing only the minimal available information).

### API Gateway (V1 & V2)
There are two different API Gateway versions (V1 & V2) that differ slightly in the information (`event` object) that is passed to the Lambda handler function.

With both versions, the `event` object contains information about the http request.
Usually API Gateway-based Lambda functions return an object that contains the HTTP response information.
The agent should use the information in the request and response objects to fill the HTTP context (`context.request` and `context.response`) fields in the same way it is done for HTTP transactions.

In particular, agents must use the `event.headers` to retrieve the `traceparent` and the `tracestate` and use them to start the transaction for the lambda function execution.

In addition the following fields should be set for API Gateway-based Lambda functions:

Field | Value | Description | Source
---   | ---   | ---         | ---
`type` | `request`| Transaction type: constant value for API gateway. | -
`name` | e.g. `GET /prod/proxy/{proxy+}` | Transaction name: Http method followed by a whitespace and the (resource) path. See section below. | -
`transaction.result` | `HTTP Xxx` / `success` | `HTTP 5xx` if there was a function error (see [Lambda error handling doc](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html#services-apigateway-errors). If the [invocation response has a "statusCode" field](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html#http-api-develop-integrations-lambda.response), then set to `HTTP Xxx` based on the status code, otherwise `success`. | Error or `response.statusCode`.
`faas.trigger.type` | `http` | Constant value for API gateway. | -
`faas.trigger.request_id` | e.g. `afa4-a6...` | ID of the API gateway request. | `event.requestContext.requestId`
`context.service.origin.name` | e.g. `gdnrpwmtsb...amazonaws.com` | The full domain name of the API Gateway. | `event.requestContext.domainName`
`context.service.origin.id` | e.g. `gy415nu...` | `event.requestContext.apiId` |
`context.service.origin.version` | e.g. `1.0` | `1.0` for API Gateway V1, `2.0` for API Gateway V2. | `event.version` (or `1.0` if that field is not present)
`context.cloud.origin.service.name` | `api gateway` | Fix value for API gateway. | -
`context.cloud.origin.account.id` | e.g. `12345678912` | Account ID of the API gateway. | `event.requestContext.accountId`
`context.cloud.origin.provider` | `aws` | Use `aws` as fix value. | -

**Set `transaction.name` for the API Gateway trigger**

There are different ways to setup an API Gateway in AWS resulting in different payload format verions:
* ["HTTP" proxy integrations](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html) can be configured to use payload format 1.0 or 2.0.
* The older ["REST" proxy integrations](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format) use payload format version 1.0.

For both payload format verions (1.0 and 2.0), the general pattern is `$method $resourcePath` (unless the `use_path_as_transaction_name` agent config option is used). Some examples are:
* `GET /prod/some/resource/path` (specific resource path)
* `GET /prod/proxy/{proxy+}` (proxy in v1.0 with dynamic path)
* `POST /prod/$default` (proxy in v2.0 with dynamic path)

*Payload format version 1.0:*

For payload format version 1.0, use `${event.resourceContext.httpMethod} /${event.requestContext.stage}${event.requestContext.resourcePath}`.

If `use_path_as_transaction_name` is applicable and set to `true`, use `${event.resourceContext.httpMethod}  /${event.requestContext.path}` as the transaction name.

*Payload format version 2.0:*

For [payload format version](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html) 2.0 (which can be identified as having `${event.requestContext.http}`), use `${event.requestContext.http.method} /${event.requestContext.stage}${_routeKey_}`.

In version 2.0, the `${event.requestContext.routeKey}` can have the format `GET /some/path`, `ANY /some/path` or `$default`. For the `_routeKey_` part,  extract the path (after the space) in the `${event.requestContext.routeKey}` or use `/$default`, in case of `$default` value in `${event.requestContext.routeKey}`.

If `use_path_as_transaction_name` is applicable and set to `true`, use `${event.resourceContext.http.method}  /${event.requestContext.http.path}` as the transaction name.

### SQS / SNS
Lambda functions that are triggered by SQS (or SNS) accept an `event` input that may contain one or more SQS / SNS messages in the `event.records` array. All message-related context information (including the `traceparent`) is encoded in the individual message attributes (if at all). We cannot (automatically) wrap the processing of the individual messages that are sent as a batch of messages with a single `event`.

Thus, in case that an SQS / SNS `event` contains **exactly one** SQS / SNS message, the agents must apply the following, messaging-specific retrieval of information. Otherwise, the agents should apply the [Generic Lambda Instrumentation](generic-lambda-instrumentation) as described above.

With only one message in `event.records`, the agents can use the single SQS / SNS `record` to retrieve the `traceparent` and `tracestate` from `record.messageAttributes` and use it for starting the lambda transaction.

In addition the following fields should be set for Lambda functions triggered by SQS or SNS:

#### SQS
Field | Value | Description | Source
---   | ---   | ---         | ---
`type` | `messaging`| Transaction type: constant value for SQS. | -
`name` | e.g. `RECEIVE SomeQueue` | Transaction name: Follow the [messaging spec](./tracing-instrumentation-messaging.md) for transaction naming. | Simple queue name can be derived from the 6th segment of `record.eventSourceArn`.
`faas.trigger.type` | `pubsub` | Constant value for message based triggers | -
`faas.trigger.request_id` | e.g. `someMessageId` | SQS message ID. | `record.messageId`
`context.service.origin.name` | e.g. `my-queue` | SQS queue name | Simple queue name can be derived from the 6th segment of `record.eventSourceArn`.
`context.service.origin.id` | e.g. `arn:aws:sqs:us-east-2:123456789012:my-queue` | SQS queue ARN. | `record.eventSourceArn`
`context.cloud.origin.service.name` | `sqs` | Fix value for SQS. | -
`context.cloud.origin.region` | e.g. `us-east-1` | SQS queue region. | `record.awsRegion`
`context.cloud.origin.account.id` | e.g. `12345678912` | Account ID of the SQS queue. | Parse account segment (5th) from `record.eventSourceArn`.
`context.cloud.origin.provider` | `aws` | Use `aws` as fix value. | -
`context.message.queue.name` | e.g. `my-queue` | The SQS queue name. | The 6th segment of `record.eventSourceArn`
`context.message.age.ms` | e.g. `3298` | Age of the message in milliseconds. `current_time` - `SentTimestamp`, if SentTimestamp is available.  | Message attribute with key `SentTimestamp`.
`context.message.body` | - | The message body. Should only be captured if body capturing is enabled in the configuration. | `record.body`
`context.message.headers` | - | The message attributes. Should only be captured, if capturing headers is enabled in the configuration. | `record.messageAttributes`

#### SNS
Field | Value | Description | Source
---   | ---   | ---         | ---
`type` | `messaging`| Transaction type: constant value for SNS. | -
`name` | e.g. `RECEIVE SomeTopic` | Transaction name: Follow the [messaging spec](./tracing-instrumentation-messaging.md) for transaction naming. | Simple topic name can be derived from the 6th segment of `record.sns.topicArn`.
`faas.trigger.type` | `pubsub` | Constant value for message based triggers | -
`faas.trigger.reuqest_id` | e.g. `someMessageId` | SNS message ID. | `record.sns.messageId`
`context.service.origin.name` | e.g. `my-topic` | SNS topic name | Simple topic name can be derived from the 6th segment of `record.sns.topicArn`.
`context.service.origin.id` | e.g. `arn:aws:sns:us-east-2:123456789012:my-topic` | SNS topic ARN. | `record.sns.topicArn`
`context.service.origin.version` | e.g. `2.1` | SNS event version | `record.eventVersion`
`context.cloud.origin.service.name` | `sns` | Fix value for SNS. | -
`context.cloud.origin.region` | e.g. `us-east-1` | SNS topic region. | Parse region segment (4th) from `record.sns.topicArn`.
`context.cloud.origin.account.id` | e.g. `12345678912` | Account ID of the SNS topic. | Parse account segment (5th) from `record.sns.topicArn`.
`context.cloud.origin.provider` | `aws` | Use `aws` as fix value. | -
`context.message.queue.name` | e.g. `my-topic` | The SNS topic name. | The 6th segment of `record.sns.topicArn`
`context.message.age.ms` | e.g. `3298` | Age of the message in milliseconds. `current_time` - `snsTimestamp`.  | `record.sns.timestamp`
`context.message.body` | - | The message body. Should only be captured if body capturing is enabled in the configuration. | `record.sns.message`
`context.message.headers` | - | The message attributes. Should only be captured, if capturing headers is enabled in the configuration. | `record.sns.messageAttributes`

### S3
Lambda functions that are triggered by S3 accept an `event` input that may contain one ore more `S3 event notification records` in the `event.records` array. We cannot (automatically) wrap the processing of the individual records that are sent as a batch of S3 event notification records with a single `event`.

Thus, in case that an S3 `event` contains **exactly one** `S3 event notification record`, the agents must apply the following, S3-specific retrieval of information. Otherwise, the agents should apply the [Generic Lambda Instrumentation](generic-lambda-instrumentation) as desribed above.

In addition the following fields should be set for Lambda functions triggered by S3:

Field | Value | Description | Source
---   | ---   | ---         | ---
`type` | `request`| Transaction type: constant value for S3. | -
`name` | e.g. `ObjectCreated:Put mybucket` | Transaction name: Use event name and bucket name. | `${record.eventName} ${record.s3.bucket.name}`
`faas.trigger.type` | `datasource` | Constant value. | -
`faas.trigger.reuqest_id` | e.g. `C3D13FE58DE4C810`| S3 event request ID. | `record.responseElements.xAmzRequestId`
`context.service.origin.name` | e.g. `mybucket` | S3 bucket name. | `record.s3.bucket.name`
`context.service.origin.id` | e.g. `arn:aws:s3:::mybucket` | S3 bucket ARN. | `record.s3.bucket.arn`
`context.service.origin.version` | e.g. `2.1` | S3 event version. | `record.eventVersion`
`context.cloud.origin.service.name` | `s3` | Fix value for S3. | -
`context.cloud.origin.region` | e.g. `us-east-1` | S3 bucket region. | `record.awsRegion`
`context.cloud.origin.provider` | `aws` | Use `aws` as fix value. | -

## Data Flushing
Lambda functions are immediately frozen as soon as the handler method ends. In case APM data is sent in an asyncronous way (as most of the agents do by default) data can get lost if not sent before the lambda function ends.

Therefore, the Lambda instrumentation has to ensure that data is flushed in a blocking way before the execution of the handler function ends.
