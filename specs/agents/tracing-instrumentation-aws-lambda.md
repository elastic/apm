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
`transaction.name` | e.g. `MyFunctionName` | The name of the Lambda function. This can be retrieveed either from the `context` object or from the environment variable `AWS_LAMBDA_FUNCTION_NAME`
`service.framework.name` | `AWS Lambda` | 
`transaction.type` | `request` |  
`faas.coldstart` | `true` / `false` | Boolean value indicating whether a Lambda function invocation was a cold start or not.
`faas.trigger`| `other` | The trigger type. Use `other` if trigger type is unknown / cannot be specified.

### Overwriting Meta-data
Automatically capturing cloud meta-data doesn't work reliably from a Lambda environment. Therefore, the generic cloud meta-data fetching should be disabled (for instance through config in the corresponding lambda layer) when the agent is running in a lambda context.
Instead, for AWS Lambda we create a dedicated meta-data fetcher that uses available environment variables to derive / overwrite the following fields:

Field | Value | Description 
---   | ---   | ---
`cloud.provider` | `aws` | The name of the Lambda function. This can be retrieveed either from the `context` object or from the environment variable `AWS_LAMBDA_FUNCTION_NAME`
`cloud.region` | e.g. `us-east-1` | The cloud region derived from the `AWS_REGION` environment variable.
`cloud.service.name` | `lambda` |  The AWS service which is the value `lambda` for this instrumentation. 
`service.runtime.name`| e.g. `AWS_Lambda_java8` | The lambda runtime derived from the `AWS_EXECUTION_ENV` environment variable.
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

In addition the following fields should be set for API Gateway-based Lambda functions:
Field | Value | Description 
---   | ---   | ---
`faas.trigger` | `http` | 
`faas.execution` | e.g. `123456789` | Use the API Gateway request ID.

With both API Gateway versions the `event` objects (may) contain a timestamp of the original API Gateway request.
This information should be used to [adapt the transaction and spans structure](#init-spans) of the Lambda invocation to represent the initialization time.

### SQS

TODO: How to deal with batch messages

In addition the following fields should be set for SQS-based Lambda functions:
Field | Value | Description 
---   | ---   | ---
`faas.trigger` | `pubsub` | 
`faas.execution` | e.g. `someMessageId` | Use the SQS message ID.
`context.message.queue` | e.g. `arn:aws:sqs:us-east-2:123456789012:my-queue` | The SQS event source ARN.
`context.message.age` | e.g. `3298` | Age of the message in milliseconds. `current_time` - `SentTimestamp`, if SentTimestamp is available. Can be retrieved from message attributes with key `SentTimestamp`.
`context.message.body` |  | The message body, only captured if body capturing is enabled in the configuration.
`context.message.headers` |  | The message headers / attributes, only if capturing headers is enabled in the configuration.

### SNS

### S3

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


## Deployment models
