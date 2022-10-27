# Tracing Azure Functions

An Azure Function Application can implement one or more handler functions that are executed when the function is invoked.
Depending on the [Azure Functions runtime language and version](https://learn.microsoft.com/en-us/azure/azure-functions/supported-languages) used the signature of this handler function will vary, of course.

In general however, there is always a *generic context* object available (e.g. [`FunctionContext`](https://learn.microsoft.com/en-us/dotnet/api/microsoft.azure.functions.worker.functioncontext)) that provides metadata and context for an instrumentation.

Depending on the actual kind of invocation (trigger type) there might be an additional object to retrieve metadata and context from.
In case of an HTTP invocation/trigger there is e.g. [`HttpRequestData`](https://learn.microsoft.com/en-us/dotnet/api/microsoft.identitymodel.protocols.httprequestdata).

## Generic Instrumentation

In general, to instrument an Azure Functions application, we create transactions that wrap the execution of its handler methods. In cases where we cannot assume any trigger type or extract trigger-specific data (e.g. if the trigger type is unsupported),
we wrap the handler method with a transaction, while using the generic context object to derive necessary fields:

| Field | Value | Description | Source |
| - | - | - | - |
| `name` | e.g. `MySampleTrigger` | The transaction name. Use function name if trigger type is `other`. | *generic context* |
| `type` | e.g. `request`, `messaging` | The transaction type. | Use `request` if trigger type is undefined. |
| `outcome` | `success`/`failure` | Set to `failure` if a function error can be detected otherwise `success`. | |
| `result` | `success`/`failure` |Set to `failure` if a function error can be detected, otherwise `success`. | Trigger specific. |
| `faas.name` | e.g. `MySampleTrigger` | The function name. | *generic context* |
| `faas.id` | e.g. `/subscriptions/d2ba53be-0815-4...` | The [fully qualified resource ID](https://learn.microsoft.com/en-us/rest/api/resources/resources/get-by-id) of the Azure Function, which has this format: `/subscriptions/<SUBSCRIPTION_GUID>/resourceGroups/<RG>/providers/Microsoft.Web/sites/<FUNCAPP>/functions/<FUNC>` | *generic context*, environment |
| `faas.trigger.type` | `other` | The trigger type. Use `other` if the trigger type is unknown or cannot be specified. | More concrete triggers are `http`, `pubsub`, `datasource`, `timer` (see specific triggers below). |

| `faas.execution` | `203621a2-62f...` | The unique invocation id of the function. | *generic context* |
| `faas.coldstart` | `true`/`false` | A boolean value indicating whether this function invocation was a cold start or not. | [see section below](deriving-cold-starts)

### Metadata

Automatically capturing cloud metadata doesn't work reliably from a Lambda environment. Moreover, retrieving cloud metadata through an additional HTTP request may slowdown the lambda function / increase cold start behaviour. Therefore, the generic cloud metadata fetching should be disabled when the agent is running in a lambda context (for instance through checking for the existence of the `AWS_LAMBDA_FUNCTION_NAME` environment variable).
Where possible, metadata should be overwritten at Lambda runtime startup corresponding to the field specifications in this spec.

The following metadata fields are relevant for lambda functions:

| Field | Value | Description | Source |
| - | - | - | - |
| `service.name`| e.g. `MyFunctionApp` | If the service name is *explicitly* specified through the `service_name` agent config option, use the configured name. Otherwise, use the name of the Lambda function. | If the service name is not explicitly configured, use the Lambda function name: `AWS_LAMBDA_FUNCTION_NAME` or `context.functionName`
`service.version` | e.g. `$LATEST` | If the service version is *explicitly* specified through the `service_version` agent config option, use the configured version. Otherwise, use the lambda function version. | If the service version is not explicitly configured, use the Lambda function version: `AWS_LAMBDA_FUNCTION_VERSION` or `context.functionVersion`
`service.framework.name` | `Azure Functions` | Constant value for the framework name. | -
`service.runtime.name`| e.g. `AWS_Lambda_java8` | The lambda runtime. | `AWS_EXECUTION_ENV`
`service.node.configured_name` | e.g. `2019/06/07/[$LATEST]e6f...` | The log stream name uniquely identifying a function instance. | `AWS_LAMBDA_LOG_STREAM_NAME` or `context.logStreamName`
`cloud.provider` | `azure` | Constant value for the cloud provider. | -
`cloud.region` | e.g. `us-east-1` | The cloud region. | `AWS_REGION`
`cloud.service.name` | `lambda` |  Constant value for the AWS service.
`cloud.account.id` | e.g. `123456789012` | The cloud account id of the lambda function. | 5th fragment in `context.invokedFunctionArn`.

### Deriving cold starts

A cold start occurs if AWS needs first to initialize the Lambda runtime (including the Lambda process, such as JVM, Node.js process, etc.) in order to handle a request. This happens for the first request and after long function idle times. A Lambda function instance only executes one event at a time (there is no concurrency). Thus, detecting a cold start is as simple as detecting whether the invocation of a __handler method__ is the **first since process startup** or not. This can be achieved with a global / process-scoped flag that is flipped at the first execution of the handler method.

### Disabled Functionality

The following agent functionalities SHOULD to be turned off when tracing Azure Functions until decided otherwise:

* **Metrics collection:** this includes all kind of metrics: system, process and breakdown metrics and is equivalent to
setting `ELASTIC_APM_METRICS_INTERVAL = 0`
* **Remote configuration:** equivalent to setting `ELASTIC_APM_CENTRAL_CONFIG = false`
* **Cloud metadata discovery:** equivalent to setting `ELASTIC_APM_CLOUD_PROVIDER = none`
* **System metadata discovery:** in some agents, this may be a relatively heavy task. For example, the Java agent
executes extenal commands in order to discover the hostname, which is not required for AWS Lambda metadata. All other
agents read and parse files to extract container and k8s metadata, which is not required as well.

There are two main approaches for agents to disable the above functionalities:

* Agents that will be always deployed as part of an additional APM Agent Lambda layer (e.g. Java agent) may disable this
through configuration options (e.g. environment variables) built in the lambda wrapper script(`AWS_LAMBDA_EXEC_WRAPPER`)
that is provided with the APM Agent Lambda layer.
* Agents that will be used with AWS lambda without the need for an additional Lambda layer must detect that they are
running in an AWS Lambda environment (for instance through checking for the existence of the `AWS_LAMBDA_FUNCTION_NAME`
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

### HTTP Invocations

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
`context.cloud.origin.service.name` | `api gateway` or `lambda url` | Constant value. | Detect lambda URLs by searching for `.lambda-url.` in the `event.requestContext.domainName`. Otherwise assume API Gateway.
`context.cloud.origin.account.id` | e.g. `12345678912` | Account ID of the API gateway. | `event.requestContext.accountId`
`context.cloud.origin.provider` | `aws` | Use `aws` as constant value. | -

**Set `transaction.name` for the API Gateway trigger**

There are different ways to setup an API Gateway in AWS resulting in different payload format versions:
* ["HTTP" proxy integrations](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html) can be configured to use payload format 1.0 or 2.0.
* The older ["REST" proxy integrations](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format) use payload format version 1.0.

For both payload format versions (1.0 and 2.0), the general pattern is `$method $resourcePath` (unless the `use_path_as_transaction_name` agent config option is used). Some examples are:
* `GET /prod/some/resource/path` (specific resource path)
* `GET /prod/proxy/{proxy+}` (proxy in v1.0 with dynamic path)
* `POST /prod/$default` (proxy in v2.0 with dynamic path)

*Payload format version 1.0:*

For payload format version 1.0, use `${event.requestContext.httpMethod} /${event.requestContext.stage}${event.requestContext.resourcePath}`.

If `use_path_as_transaction_name` is applicable and set to `true`, use `${event.requestContext.httpMethod} ${event.requestContext.path}` as the transaction name.

*Payload format version 2.0:*

For [payload format version](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html) 2.0 (which can be identified as having `${event.requestContext.http}`), use `${event.requestContext.http.method} /${event.requestContext.stage}${_routeKey_}`.

In version 2.0, the `${event.requestContext.routeKey}` can have the format `GET /some/path`, `ANY /some/path` or `$default`. For the `_routeKey_` part, extract the path (after the space) in the `${event.requestContext.routeKey}` or use `/$default`, in case of `$default` value in `${event.requestContext.routeKey}`.

If `use_path_as_transaction_name` is applicable and set to `true`, use `${event.requestContext.http.method} ${event.requestContext.http.path}` as the transaction name.

