# AWS Lambda instrumentation
This spec specifies the instrumentation of applications / services running on AWS Lambda.

An AWS Lambda application needs to implement a **handler method** that is called whenever that Lambda function is invoked. A handler method receives (at least) two objects with useful information:
- `event`: Depending on the trigger type of the Lambda function this object contains different, trigger-specific data. For some trigger types this object may be empty/null.
- `context`: This object provides generic (trigger agnostic) meta information about the Lambda function.

In our instrumentation we use these objects to derive useful meta and context information.

## Generic Lambda Instrumentation
In general, to instrument Lambda functions, we create transactions that wrap the execution of that handler method. In cases where we cannot assume any type or information in the `event` object (e.g. if the trigger type is undefined), we ignore trigger-specific information and simply wrap the handler method with a transaction, while using the `context` object to derive some necessary fields.

Field | Value | Description 
---   | ---   | ---
`transaction.name` | e.g. `MyFunctionName` | The name of the Lambda function. This can be retrieved either from the `context` object or from the environment variable `AWS_LAMBDA_FUNCTION_NAME`
`transaction.type` | `request` |  
`faas.id` | e.g. `arn:aws:lambda:us-west-2:123456789012:function:my-function` | Use `context.invokedFunctionArn` to set the id. 
`faas.coldstart` | `true` / `false` | Boolean value indicating whether a Lambda function invocation was a cold start or not.
`faas.trigger.type`| `other` | The trigger type. Use `other` if trigger type is unknown / cannot be specified. More concrete triggers are `http`, `pubsub`, `datasource`, `timer` (see specific triggers below).

### Overwriting Metadata
Automatically capturing cloud metadata doesn't work reliably from a Lambda environment. Moreover, retrieving cloud metadata through an additional HTTP request may slowdown the lambda function / increase cold start behaviour. Therefore, the generic cloud metadata fetching should be disabled when the agent is running in a lambda context (for instance through checking for the existance of the `AWS_LAMBDA_FUNCTION_NAME` environment variable). For AWS Lambda we adapt meta-data fetching that uses available environment variables to derive / overwrite the following fields:

Field | Value | Description 
---   | ---   | ---
`service.name` | e.g. `MyFunctionName` | The name of the Lambda function. Retrieved from the environment variable `AWS_LAMBDA_FUNCTION_NAME`.
`service.framework.name` | `AWS Lambda` | Contant value for the framework name.
`service.runtime.name`| e.g. `AWS_Lambda_java8` | The lambda runtime derived from the `AWS_EXECUTION_ENV` environment variable.
`cloud.provider` | `aws` | Contant value for the cloud provider.
`cloud.region` | e.g. `us-east-1` | The cloud region derived from the `AWS_REGION` environment variable.
`cloud.service.name` | `lambda` |  The AWS service which is the value `lambda` for this instrumentation. 
`faas.name` | e.g. `MyFunctionName` | The lambda function name derived from the `AWS_LAMBDA_FUNCTION_NAME` environment variable.
`faas.version`| e.g. `${LATEST}` | The lambda function version derived from the `AWS_LAMBDA_FUNCTION_VERSION` environment variable.


### Deriving cold starts 
A cold start occurs if AWS needs first to initialize the Lambda runtime (including the Lambda process, such as JVM, Node.js process, etc.) in oder to handle a request. This happens for the first request and after long function idle times. Lambda functions are always called sequentially (there is no concurrency). Thus, detecting a cold start is as simple as detecting whether the invocation of a __handler method__ is the **first since process startup** or not. This can be achieved with a global / process-scoped flag that is flipped at the first execution of the handler method.



## Trigger-specific Instrumentation
Lambda functions can be triggered in many different ways. A generic transaction for a Lambda invocation can be create independently of the actual trigger. However, depending on the trigger type different information might be available that can be used to capture additional transaction data or allows to derive additional, valuable spans. The most common triggers that we want dedicated instrumentation support for are the following:  

- API Gateway V1 
- API Gateway V2 
- SQS
- SNS
- S3

If none of the above apply, the fallback should be a generic instrumentation (as described above) that can deal with any type of trigger (thus capturing only the minimal available information).

### API Gateway (V1 & V2)
There are two different API Gateway versions (V1 & V2) that slightly differ in the information (`event` object) that is passed to the Lambda handler function. 

With both versions, the `event` object contains information about the http request.
Usually API Gateway-based Lambda functions return an object that contains the HTTP response information.
The agent should use the information in the request and response objects to fill the HTTP context (`context.request` and `context.response`) fields in the same way it is done for HTTP transactions.

In particular, agents must use the `event.headers` to retrieve the `traceparent` and the `tracestate` and use them to start the transaction for the lambda function execution. 

In addition the following fields should be set for API Gateway-based Lambda functions:
Field | Value | Description 
---   | ---   | ---
`faas.trigger.type` | `http` | 
`faas.trigger.id` | e.g. `gy415nuibc` | Use `event.requestContext.apiId`
`faas.trigger.name` | e.g. `POST /{proxy+}/Prod` | Format: `${event.requestContext.httpMethod} ${event.requestContext.resourcePath}/${event.requestContext.stage}`
`faas.trigger.account.id` | e.g. `12345678912` | Use `event.requestContext.accountId`
`faas.trigger.version` | `1.0` or `2.0` | `1.0` for API Gateway V1, `2.0` for API Gateway V2
`faas.execution` | e.g. `123456789` | Use `event.requestContext.requestId`

With both API Gateway versions the `event` objects (may) contain a timestamp of the original API Gateway request.
This information should be used to [adapt the transaction and spans structure](#init-spans) of the Lambda invocation to represent the initialization time.

### SQS / SNS
Lambda functions that are triggered by SQS (or SNS) accept an `event` input that may contain one ore more SQS / SNS messages in the `event.records` array. All message-related context information (including the `traceparent`) is encoded in the individual message attributes (if at all). We cannot (automatically) wrap the processing of the individual messages that are sent as a batch of messages with a single `event`. 

Thus, in case that an SQS / SNS `event` contains **exactly one** SQS / SNS message, the agents must apply the following, messaging-specific retrieval of information. Otherwise, the agents should apply the [Generic Lambda Instrumentation](generic-lambda-instrumentation) as desribed above.

With only one message in `event.records`, the agents can use the single SQS / SNS `record` to retrieve the `traceparent` and `tracestate` from `record.messageAttributes` and use it for starting the lambda transaction. 

In addition the following fields should be set for Lambda functions triggered by SQS or SNS:
Field | Value | SQS | SNS
---   | ---   | --- | ---
`faas.trigger.type` | `pubsub` | Constant value for message based triggers | "
`faas.trigger.id` | e.g. `arn:aws:sqs:us-east-2:123456789012:my-queue` | Use `record.eventSourceArn` |Use `record.sns.topicArn`
`faas.trigger.name` | e.g. `my-queue` | Parse the queue / topic name (6th element) from the ARN used for `faas.trigger.id`. | "
`faas.trigger.account.id` | e.g. `12345678912` | Parse account segment (5th) from the ARN used for `faas.trigger.id` | " 
`faas.trigger.region` | e.g. `us-east-1` |  Use `record.awsRegion` | Parse region segment (4th) from `record.sns.topicArn`
`faas.trigger.version` | e.g. `2.1` | Use `record.eventVersion` | not available
`faas.execution` | e.g. `someMessageId` | Use `record.messageId` | Use `record.sns.messageId`
`context.message.queue` | e.g. `arn:aws:sqs:us-east-2:123456789012:my-queue` | Use `record.eventSourceArn` | Use `record.sns.topicArn`
`context.message.age` | e.g. `3298` | Age of the message in milliseconds. `current_time` - `SentTimestamp`, if SentTimestamp is available. </br></br> For SQS, the timestamp can be retrieved from message attributes with key `SentTimestamp`. | Age of the message in milliseconds. `current_time` - `SentTimestamp`, if SentTimestamp is available. </br></br> For SNS, the timestamp can be retrieved from `record.sns.timestamp`.
`context.message.body` |  | The message body. Sould only be captured if body capturing is enabled in the configuration.</br></br> Use `record.body` | The message body. Sould only be captured if body capturing is enabled in the configuration.</br></br> Use `record.sns.message`
`context.message.headers` |  | The message attributes. Should only be captured, if capturing headers is enabled in the configuration.</br></br> Use `record.messageAttributes`| The message attributes. Should only be captured, if capturing headers is enabled in the configuration.</br></br> Use `record.sns.messageAttributes`


### S3
Lambda functions that are triggered by S3 accept an `event` input that may contain one ore more `S3 event notification records` in the `event.records` array. We cannot (automatically) wrap the processing of the individual records that are sent as a batch of S3 event notification records with a single `event`. 

Thus, in case that an S3 `event` contains **exactly one** `S3 event notification record`, the agents must apply the following, S3-specific retrieval of information. Otherwise, the agents should apply the [Generic Lambda Instrumentation](generic-lambda-instrumentation) as desribed above.

In addition the following fields should be set for Lambda functions triggered by S3:
Field | Value | Description 
---   | ---   | ---
`faas.trigger.type` | `datasource` | Constant value for message based triggers.
`faas.trigger.name` | e.g. `mybucket` | Use `record.s3.bucket.name`
`faas.trigger.id` | e.g. `arn:aws:s3:::mybucket/ObjectCreated:Put` | Use `record.s3.bucket.arn`
`faas.trigger.region` | e.g. `us-east-1` | Use `record.awsRegion`
`faas.trigger.version` | e.g. `2.1` | Use `record.eventVersion`
`faas.execution` | e.g. `arn:aws:s3:::mybucket/ObjectCreated:Put` | Format: `${record.s3.bucket.arn}/${record.eventName}`


## Init spans
With both API Gateway versions the `event` objects (may) contain a timestamp of the original API Gateway request. The difference between the API Gateway timestamp and the actual start timestamp of the Lambda function is a good estimate for the initialization phase of the lambda function. 
The agents should use this information (if available) to adapt the transaction and spans structure of the Lambda invocation to represent the initialization time:

```
...
  [XXXXXXXXXXXXX POST api.gateway XXXXXXXXXXXXXXXXXXXXX]   // client calling the API Gateway
     [XXXXXXXXXX MyLambdaFunction XXXXXXXXXXXXXXXXXXXX]    // Lambda Transaction
     [XXX Lambda init XXXXX]                               // Init span
                            [XXXX Lambda handler XXXX]      // span for the handler method
                                    [XXXXXXXXXX]           // any Lambda subspans
     ^                      ^
     |                      |
API Gateway               Timestamp of the
RequestTimestamp          handler method start
```

To achieve the above transaction / span structure we need to backdate the begin of the created transaction using the API Gateway timestamp. We create a artificial span `Lambda init` using the API Gateway timestamp as start and the handler method timestamp as end. The `Lambda handler` span represents the actual execution of the Lambda handler method. 

### Retrieving the API Gateway V1 timestamp
With API Gateway version 1 there is no dedicated request timestamp field. 
However, AWS adds a X-Ray tracing ID to the headers which encodes a request timestamp in **seconds**.
Though the resolution of that timestamp is very coarse grained, in some cases it still can provide at least a rough estimate of the init phase (if the init phase is very long).

The agents should use this timestamp and apply the above transaction structure if:
- the corresponding header is available 
- AND: `x_ray_api_gateway_request_timestamp` + 1 second < `handler_method_start_timestamp`

The X-Ray timestamp can be retrieved from the HTTP header `X-Amzn-Trace-Id`. The trace id has the following format: 
```
1-58406520-a006649127e371903a2de979
```

The second segment (here: `58406520`) is a hexadecimal encoded timestamp in seconds.

### Retrieving the API Gateway V2 timestamp
With API Gateway version 2 the passed `event` object contains a field `timeEpoch` field (under `request context`) that denotes the request timestamp in milliseconds. 

## Data Flushing
Lambda functions are immediately frozen as soon as the handler method ends. In case APM data is sent in an asyncronous way (as most of the agents do by default) data can get lost if not sent before the lambda function ends.

Therefore, the Lambda instrumentation has to ensure that data is flushed in a blocking way before the execution of the handler function ends. Where possible, agents may optimize the flushing behaviour by avoiding a dedicated HTTP request for each Lambda invocation but instead flushing the buffer on the HTTP connection: 

- Waits until all pending events have been processed
- Performs a synced_flush on the gzip buffer and flushes all buffers to the network
- Keeps the HTTP request alive
- Returns immediately if the connection to APM Server is unhealthy (when there's a backoff)
