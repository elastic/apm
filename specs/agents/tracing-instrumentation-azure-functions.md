# Tracing Azure Functions

An Azure Function Application can implement one or more handler functions that are executed via different trigger mechanisms (e.g. HTTP).
Depending on these trigger mechanisms and the actual [Azure Functions runtime language and version](https://learn.microsoft.com/en-us/azure/azure-functions/supported-languages),
the signature of these handler functions will vary, of course.

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

Generic cloud metadata fetching SHOULD be disabled when the agent is running in an Azure Functions app. It will not
yield any useful data and only incur additional cold start overhead due to the non-existent HTTP metadata endpoints.

Agents SHOULD rather:

* Check for the existence of the `FUNCTIONS_WORKER_RUNTIME` environment variable that indicates that the agent is running
in an Azure Function application.
* Perform specific cloud metadata detection for Azure Functions (see [Metadata](./metadata.md)).

In addition to those described in [Metadata](./metadata.md), following metadata fields are relevant for Azure Functions:

| Field | Value | Description | Source |
| - | - | - | - |
| `service.framework.name` | `Azure Functions` | Constant value for the framework name. | |
| `service.runtime.name`| e.g. `dotnet-isolated` | The language worker runtime (see [here](https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings#functions_worker_runtime)). | `FUNCTIONS_WORKER_RUNTIME` |

### Deriving cold starts

A cold start occurs if the Azure Functions runtime needs to be initialized in order to handle the first function execution.
Since an Azure Function app can provide multiple function entry points, those may run concurrently.
Hence, cold start detection must happen in a thread-safe manner.

**Note:** The Azure Functions [Premium plan](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale)
guarantees pre-warmed workers (no cold starts). Nonetheless, reporting the first function execution as such might still make
sense since it could come with additional processing due to function-specific initialization overhead or JIT costs.  
Alternatively, agents could try to detect their hosting plan and not report cold starts for Premium plans at all.

### Disabled Functionality

Agents SHOULD detect whether they are running in an Azure Functions environment by testing
for the existence of the `FUNCTIONS_WORKER_RUNTIME` environment variable.

The following agent functionalities SHOULD to be turned off when tracing Azure Functions until decided otherwise:

* **Metrics collection:** this includes all kind of metrics: system, process and breakdown metrics and is equivalent to
setting `ELASTIC_APM_METRICS_INTERVAL = 0`
* **Remote configuration:** equivalent to setting `ELASTIC_APM_CENTRAL_CONFIG = false`
* **Cloud metadata discovery:**
  * Equivalent to setting `ELASTIC_APM_CLOUD_PROVIDER = none`
  * Instead an Azure Functions specific metadata detection MUST be performed (see see [Metadata](./metadata.md)).
* **System metadata discovery:** in some agents, this may be a relatively heavy task. For example, the Java agent
executes external commands in order to discover the hostname, which is not required for tracing Azure Functions. All other
agents read and parse files to extract container and k8s metadata, which is not required as well.

## Trigger-Specific Instrumentation

Azure Functions can be triggered in [many different ways](https://learn.microsoft.com/en-us/azure/azure-functions/functions-triggers-bindings).
A generic transaction for an Azure Functions invocation can be created independently of the actual trigger
based on the [generic instrumentation](#generic-instrumentation) fields described above.

However, depending on the trigger type, different information might be available that can be used
to capture additional transaction data or that allows additional, valuable spans to be derived.

### HTTP Trigger

HTTP invocations typically provide *some* variants of an HTTP *request object* (e.g. [`HttpRequestData`](https://learn.microsoft.com/en-us/dotnet/api/microsoft.identitymodel.protocols.httprequestdata))
and an HTTP *response object* (e.g. [`HttpResponseData`](https://learn.microsoft.com/en-us/dotnet/api/microsoft.azure.functions.worker.http.httpresponsedata)).

Agents SHOULD use the information in the *request* and *response objects* to
fill the HTTP context (`context.request` and `context.response`) fields in the same way it is done for HTTP transactions.

In particular, agents MUST use HTTP headers to retrieve the `traceparent` and the `tracestate`
and use those to start the transaction for the tracing the function execution.

In addition the following fields should be set for HTTP trigger invocations:

| Field | Value | Description | Source |
| - | - | - | - |
| `type` | `request`| Transaction type. Constant value for HTTP trigger invocations. | |
| `name` | e.g. `GET /prod/proxy/{proxy+}` | Transaction name: HTTP method followed by a whitespace and the (resource) path. | *request object* |
| `transaction.result` | `HTTP Xxx` / `success` | `HTTP Xxx` based on the *response object* status code, otherwise `success`. | *response object* |
| `faas.trigger.type` | `http` | Constant value for HTTP trigger invocations. | |
