## Metadata

As mentioned above, the first "event" in each ND-JSON stream contains metadata to fold into subsequent events. The metadata that agents should collect is described in the following sub-sections.

 - service metadata
 - global labels (requires APM Server 7.2 or greater)

The process for proposing new metadata fields is detailed
[here](process-new-fields.md).

### System metadata

System metadata relates to the host/container in which the service being monitored is running:

 - hostname
 - architecture
 - operating system
 - container ID
 - kubernetes
   - namespace
   - node name
   - pod name
   - pod UID

#### Hostname

This hostname reported by the agent is mapped by the APM Server to the 
[`host.hostname` ECS field](https://www.elastic.co/guide/en/ecs/current/ecs-host.html#field-host-hostname), which should 
typically contain what the `hostname` command returns on the host machine. However, since we rely on this field for 
our integration with beats data, we should attempt to follow a similar logic to the `os.Hostname()` Go API, which beats 
relies one. While `os.Hostname()` contains some complex OS-specific logic to cover all sorts of edge cases, our 
algorithm should be simpler. It relies on the execution of external commands with a fallback to standard environment 
variables. Agents SHOULD implement this hostname discovery algorithm wherever possible:
```
var hostname;
if os == windows
  hostname = exec "cmd /c hostname"                   // or any equivalent *
  if (hostname == null || hostname.length == 0)
    hostname = env.get("COMPUTERNAME")
else 
  hostname = exec "uname -n"                          // or any equivalent *
  if (hostname == null || hostname.length == 0)
    hostname = exec "hostname"                        // or any equivalent *
  if (hostname == null || hostname.length == 0)
    hostname = env.get("HOSTNAME")
  if (hostname == null || hostname.length == 0)
    hostname = env.get("HOST")

if hostname != null
  hostname = hostname.trim()                          // see details below **
```
`*` this algorithm is using external commands in order to be OS-specific and language-independent, however these 
may be replaced with language-specific APIs that provide the equivalent result. The main consideration when choosing 
what to use is to avoid hostname discovery that relies on DNS lookup.

`**` in this case, `trim()` refers to the removal of all leading and trailing characters of which codepoint is less-than
or equal to `U+0020` (space).

Agents MAY use alternative approaches, but those need to generally conform to the basic concept. Failing to discover the 
proper hostname may cause failure in correlation between APM traces and data reported by other clients (e.g. 
Metricbeat). For example, if the agent uses an API that produces the FQDN, this value is likely to mismatch hostname 
reported by other clients.

In addition to auto-discovery of the hostname, agents SHOULD also expose the `ELASTIC_APM_HOSTNAME` config option that 
can be used as a manual fallback.

Up to APM Server 7.4, only the `system.hostname` field was used for this purpose. Agents communicating with 
APM Server of these versions MUST set `system.hostname` with the value of `ELASTIC_APM_HOSTNAME`, if such is manually 
configured. Otherwise, agents MUST set it with the automatically-discovered hostname.

Since APM Server 7.4, `system.hostname` field is deprecated in favour of two newer fields:
- `system.configured_hostname` - it should only be sent when configured by the user through the `ELASTIC_APM_HOSTNAME` 
config option. If provided, it is used by the APM Server as the event's hostname.
- `system.detected_hostname` - the hostname automatically detected by the APM agent. It will be used as the event's 
hostname if `configured_hostname` is not provided.

Agents that are APM-Server-version-aware, or that are compatible only with versions >= 7.4, should 
use the new fields wherever applicable.

> **_NOTE:_** We recently established that the various agents handle hostnames differently, with some sending an FQDN (when available) and others (such as the .NET agent) sending a simple hostname. To avoid breaking consumers, agents should continue sending the hostname as they already do. Logic will be introduced to split the hostname from an FQDN, when required, based on the configured feature flag. See below in the "Host domain name" section for further details of the proposed logic.

#### Host domain name

ECS 8.7 [updated](https://github.com/elastic/ecs/pull/2122) the definition of `host.name`, recommending using the 
lowercase fully qualified domain name (FQDN) for the host name. All Elastic ECS producers should populate the 
`host.name` field with the lowercased FQDN from here forward. This change is behind a 
[feature flag](https://www.elastic.co/guide/en/fleet/current/elastic-agent-standalone-feature-flags.html#elastic-agent-standalone-feature-flag-settings) 
on the Elastic agent to avoid breaking changes for users. Since APM agents do not know about the feature flag, 
this decision must happen on the APM server. To support this, APM agents should collect and send the host domain name 
(when available) to enable the APM server to construct the FQDN for `host.name` when the feature flag is enabled.

APM agents should attempt to detect the host domain name, in addition to the hostname. When detected, the lowercase domain name of the 
host should be used to set the `system.detected_domain_name` field. This will be combined with the `detected_hostname` 
to form the final FQDN.

When a `system.configured_hostname` is configured, it is the responsibility of the user to determine if 
they wish to configure this with the FQDN or just the hostname.

**Detecting the domain name**

Agents can detect the domain name using framework APIs, or OS system calls if necessary. 
For example, the .NET agent implementation will use the .NET API, 
`IPGlobalProperties.GetIPGlobalProperties().DomainName` to access the domain name 
for the host. This is provided by Microsoft as a cross-platform API and is 
therefore well-tested and supported.

On Windows, this ultimately calls down into the native  `IpHlpApi.GetNetworkParams` 
[function](https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getnetworkparams), 
collecting the information it needs from the 
`FIXED_INFO` [structure](https://learn.microsoft.com/en-us/windows/win32/api/iptypes/ns-iptypes-fixed_info_w2ksp1). 

On Linux-based systems, it uses the `getdomainname()` [Linux system call](https://man7.org/linux/man-pages/man2/getdomainname.2.html), 
and falls back to `uname` (sys/utsname.h) for other platforms such as Android. 

On .NET, while likely unnecessary, a further fallback can be introduced by accessing 
the static `Environment.UserDomainName` property. On Windows, this will 
attempt to invoke the `GetUserNameExW` [function](https://learn.microsoft.com/en-us/windows/win32/api/secext/nf-secext-getusernameexw) 
from `secext.h`, from which the username portion is then trimmed.

When not detected through OS system calls, agents should include a final fallback, 
checking the system environment variable `USERDOMAIN`, which on Windows will contain 
the name of the Windows domain the user is currently logged on to.

> **_NOTE:_** As some agents may already send an FQDN for the `detected_hostname` field, logic will be required to extract the required components. When the `detected_hostname` includes the `detected_domain_name`, the `detected_domain_name` string can be removed, along with any remaining separators, to determine the simple `hostname`. If required, the hostname and domain name can later be re-combined by the feature flag configuration. For agents that already send a simple hostname for `detected_hostname`, that hostname will not include the domain name and can safely be combined with the `detected_domain_name` (if present) when the configuration requires an FQDN to be stored for ECS `host.name`.

#### Container/Kubernetes metadata

On Linux, the container ID and some of the Kubernetes metadata can be extracted by parsing `/proc/self/cgroup`. For each line in the file, we split the line according to the format "hierarchy-ID:controller-list:cgroup-path", extracting the "cgroup-path" part. We then attempt to extract information according to the following algorithm:

 1. Split the path into `dirname` and `basename`:
    - split based on the last occurrence of the colon character, if such exists, in order to support paths of containers 
    created by [containerd-cri](https://github.com/containerd/cri), where the path part takes the form: 
    `<dirname>:cri-containerd:<container-ID>`
    - if colon char is not found within the path, the split is done based on the last occurrence of the slash character

 2. If the `basename` ends with ".scope", check for a hyphen and remove everything up to and including that. This allows 
 us to match `.../docker-<container-id>.scope` as well as `.../<container-id>`.

 3. Attempt to extract the Kubernetes pod UID from the `dirname` by matching one of the following regular expressions:
     - `(?:^/kubepods[\\S]*/pod([^/]+)$)`
     - `(?:kubepods[^/]*-pod([^/]+)\.slice)`

    If there is a match to either expression, the capturing group contains the pod ID. We then unescape underscores 
    (`_`) to hyphens (`-`) in the pod UID.
    If we match a pod UID then we record the hostname as the pod name since, by default, Kubernetes will set the 
    hostname to the pod name. Finally, we record the basename as the container ID without any further checks.

 4. If we did not match a Kubernetes pod UID above, then we check if the basename matches one of the following regular 
 expressions:

    - `^[[:xdigit:]]{64}$`
    - `^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4,}$`
    - `^[[:xdigit:]]{32}-[[:digit:]]{10}$` (AWS ECS/Fargate environments)

 If we match, then the basename is assumed to be a container ID.

If the Kubernetes pod name is not the hostname, it can be overridden by the `KUBERNETES_POD_NAME` environment variable, using the [Downward API](https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/). In a similar manner, you can inform the agent of the node name and namespace, using the environment variables `KUBERNETES_NODE_NAME` and `KUBERNETES_NAMESPACE`.

*Note:* [cgroup_parsing.json](../../tests/agents/json-specs/cgroup_parsing.json) provides test cases for parsing cgroup lines.

### Process metadata

Process level metadata relates to the process running the service being monitored:

 - process ID
 - parent process ID
 - process arguments
 - process title (e.g. "node /app/node_")

### Service metadata

Service metadata relates to the service/application being monitored:

 - service name and version
 - environment name ("production", "development", etc.)
 - agent name (e.g. "ruby") and version (e.g. "2.8.1")
 - language name (e.g. "ruby") and version (e.g. "2.5.3")
 - runtime name (e.g. "jruby") and version (e.g. "9.2.6.0")
 - framework name (e.g. "flask") and version (e.g. "1.0.2")

For official Elastic agents, the agent name should just be the name of the language for which the agent is written, in lower case.

Services running on AWS Lambda [require specific values](tracing-instrumentation-aws-lambda.md) for some of the above mentioned fields.

#### Activation method

Most of the APM Agents can be activated in several ways. Agents SHOULD collect information about the used activation method and send it in the `service.agent.activation_method` field within the metadata.
This field MUST be omitted in version `8.7.0` due to a bug in APM server (preventing properly capturing metrics).
This field SHOULD be included when the APM server version is unknown or at least `8.7.1`.

The intention of this field is to drive telemetry so there is a way to know which activation methods are commonly used. This field MUST produce data with very low cardinality, therefore agents SHOULD use one of the values defined below.

If the agent is unable to infer the activation method, it SHOULD send `unknown`.

There are some well-known activation methods which can be used by multiple agents. In those cases, agents SHOULD send the following values in `service.agent.activation_method`:

- `aws-lambda-layer`: when the agent was installed as a Lambda layer.
- `k8s-attach`: when the agent is attached via [the K8s webhook](https://github.com/elastic/apm-mutating-webhook).
- `env-attach`: when the agent is activated by setting some environment variables. Only use this if there is a single way to activate the agent via an environment variable. If the given runtime offers multiple environment variables to activate the agent, use more specific values to avoid ambiguity.
- `fleet`: when the agent is activated via fleet.

Cross agent activation methods defined above have higher priority than agent specific values below.
If none of the above matches the activation method, agents define specific values for specific scenarios.

Node.js:
- `require`: when the agent is started via CommonJS `require('elastic-apm-node').start()` or `require('elastic-apm-node/start')`.
- `import`: when the agent is started via ESM, e.g. `import 'elastic-apm-node/start.js'`.
- `preload`: when the agent is started via the Node.js `--require` flag, e.g. `node -r elastic-apm-node/start ...`, without using `NODE_OPTIONS`.

Java:
- `javaagent-flag`: when the agent is attached via the `-javaagent` JVM flag.
- `apm-agent-attach-cli`: when the agent is attached via the `apm-agent-attach-cli` tool.
- `programmatic-self-attach`: when the agent is attached by manually calling the `ElasticApmAttacher` API in user code.

.NET:
- `nuget`: when the agent was installed via a NuGet package.
- `profiler`: when the agent was installed via the CLR Profiler.
- `startup-hook`: when the agent relies on the `DOTNET_STARTUP_HOOKS` mechanism to install the agent.

Python:
- `wrapper`: when the agent was invoked with the wrapper script, `elasticapm-run`

### Cloud Provider Metadata

[Cloud provider metadata](https://github.com/elastic/apm-server/blob/main/docs/spec/v2/metadata.json)
is collected from local cloud provider metadata services:

- availability_zone
- account
  - id
  - name
- instance
  - id
  - name
- machine.type
- project
  - id
  - name
- provider (**required**)
- region

This metadata collection is controlled by a configuration value,
`CLOUD_PROVIDER`. The default is `auto`, which automatically detects the cloud
provider. If set to `none`, no cloud metadata will be generated. If set to
any of `aws`, `gcp`, or `azure`, metadata will only be generated from the
chosen provider.

Any intake API requests to the APM server should be delayed until this
metadata is available.

A sample implementation of this metadata collection is available in
[the Python agent](https://github.com/elastic/apm-agent-python/blob/main/elasticapm/utils/cloud.py).

Fetching of cloud metadata for services running as AWS Lambda functions follow a [different approach defined in the tracing-instrumentation-aws-lambda spec](tracing-instrumentation-aws-lambda.md).

#### AWS metadata

[Metadata about an EC2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html) can be retrieved from the internal metadata endpoint, `http://169.254.169.254`.

In the case where a proxy is configured on the application, the agents SHOULD attempt to make
the calls to the metadata endpoint directly, without using the proxy.
This is recommended as those HTTP calls could be caller-sensitive and have to be made directly
 by the virtual machine where the APM agent executes, also, the `169.254.x.x` IP address range
is reserved for "link-local" addresses that are not routed.

As an example with curl, first, an API token must be created

```sh
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300"`
```

Then, metadata can be retrieved, passing the API token

```sh
curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data
```

From the returned metadata, the following fields are useful

| Cloud metadata field  | AWS Metadata field  |
| --------------------  | ------------------- |
| `account.id`          | `accountId`         |
| `instance.id`         | `instanceId`        |
| `availability_zone`   | `availabilityZone`  |
| `machine.type`        | `instanceType`      |
| `provider`            | aws                 |
| `region`              | `region`            |

#### GCP metadata

Metadata about a GCP machine instance can be retrieved from the 
metadata service, `http://metadata.google.internal`.

In the case where a proxy is configured on the application, the agents SHOULD attempt to make
the calls to the metadata endpoint directly, without using the proxy.
This is recommended as those HTTP calls could be caller-sensitive and have to be made directly
 by the virtual machine where the APM agent executes, also, the `169.254.x.x` IP address range
is reserved for "link-local" addresses that are not routed.

An example with curl

```sh
curl -X GET "http://metadata.google.internal/computeMetadata/v1/?recursive=true" -H "Metadata-Flavor: Google"
```

From the returned metadata, the following fields are useful

| Cloud metadata field  | GCP Metadata field  |
| --------------------  | ------------------- |
| `instance.id`         | `instance.id`       |
| `instance.name`       | `instance.name`     |
| `project.id`          | `project.numericProjectId` as a string |
| `project.name`        | `project.projectId` |
| `availability_zone`   | last part of `instance.zone`, split by `/`  |
| `machine.type`        | last part of `instance.machineType`, split by `/` |
| `provider`            | gcp                 |
| `region`              | last part of `instance.zone`, split by `-`            |

#### Azure metadata

##### Azure VMs

Metadata about an Azure VM can be retrieved from the internal metadata
endpoint, `http://169.254.169.254`.

In the case where a proxy is configured on the application, the agents SHOULD attempt to make
the calls to the metadata endpoint directly, without using the proxy.
This is recommended as those HTTP calls could be caller-sensitive and have to be made directly
 by the virtual machine where the APM agent executes, also, the `169.254.x.x` IP address range
is reserved for "link-local" addresses that are not routed.

An example with curl

```sh
curl -X GET "http://169.254.169.254/metadata/instance/compute?api-version=2019-08-15" -H "Metadata: true"
```

From the returned metadata, the following fields are useful

| Cloud metadata field  | Azure Metadata field|
| --------------------  | ------------------- |
| `account.id`          | `subscriptionId`    |
| `instance.id`         | `vmId`              |
| `instance.name`       | `name`              |
| `project.name`        | `resourceGroupName` |
| `availability_zone`   | `zone`              |
| `machine.type`        | `vmSize`            |
| `provider`            | azure               |
| `region`              | `location`          |

##### Azure App Services _(Optional)_

Azure App Services are a PaaS offering within Azure which does not
have access to the internal metadata endpoint. Metadata about
an App Service can however be retrieved from environment variables


| Cloud metadata field  | Environment variable |
| --------------------  | ------------------- |
| `account.id`          | first part of `WEBSITE_OWNER_NAME`, split by `+` |
| `instance.id`         | `WEBSITE_INSTANCE_ID` |
| `instance.name`       | `WEBSITE_SITE_NAME` |
| `project.name`        | `WEBSITE_RESOURCE_GROUP` |
| `provider`            | azure               |
| `region`              | last part of `WEBSITE_OWNER_NAME`, split by `-`, trim end `"webspace"` and anything following |

The environment variable `WEBSITE_OWNER_NAME` has the form

```
{subscription id}+{app service plan resource group}-{region}webspace{.*}
```

an example of which is `f5940f10-2e30-3e4d-a259-63451ba6dae4+elastic-apm-AustraliaEastwebspace`

Cloud metadata for Azure App Services is optional; it is up
to each agent to determine whether it is useful to implement
for their language ecosystem. See [azure_app_service_metadata specs](../../tests/agents/gherkin-specs/azure_app_service_metadata.feature)
for scenarios and expected outcomes.

##### Azure Functions

Azure Functions running within a consumption/premium plan (see [Azure Functions hosting options](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale)) are a FaaS offering within Azure that do not have access
to the internal [Azure metadata endpoint](#azure-vms). Metadata about an Azure Function can however be
retrieved from environment variables.  
**Note:** These environment variables slightly differ from those available to [Azure App Services](#azure_app_service-optional).

| Cloud metadata field  | Environment variable |
| --------------------  | ------------------- |
| `account.id`          | Token `{subscription id}` from `WEBSITE_OWNER_NAME` |
| `instance.name`       | `WEBSITE_SITE_NAME` |
| `project.name`        | `WEBSITE_RESOURCE_GROUP` (fallback: `{resource group}` from `WEBSITE_OWNER_NAME`) |
| `provider`            | azure               |
| `region`              | `REGION_NAME`  (fallback: `{region}` from `WEBSITE_OWNER_NAME`) |
| `service.name` | `functions` see the [ECS fields doc](https://www.elastic.co/guide/en/ecs/current/ecs-cloud.html#field-cloud-service-name). |

The environment variable `WEBSITE_OWNER_NAME` has the following form:

`{subscription id}+{resource group}-{region}webspace{.*}`

Example: `d2cd53b3-acdc-4964-9563-3f5201556a81+wolfgangfaas_group-CentralUSwebspace-Linux`

### Global labels

Events sent by the agents can have labels associated, which may be useful for custom aggregations, or document-level access control. It is possible to add "global labels" to the metadata, which are labels that will be applied to all events sent by an agent. These are only understood by APM Server 7.2 or greater.

Global labels can be specified via the environment variable `ELASTIC_APM_GLOBAL_LABELS`, formatted as a comma-separated 
list of `key=value` pairs.
