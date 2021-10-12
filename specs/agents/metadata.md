## Metadata

As mentioned above, the first "event" in each ND-JSON stream contains metadata to fold into subsequent events. The metadata that agents should collect includes are described in the following sub-sections.

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
if os == windows
  ret = exec "cmd /c hostname"   
  if ret != null && ret.length > 0
    return ret
  else
    return env.get("COMPUTERNAME")
else 
  ret = exec "unamne -n" 
  if ret != null && ret.length > 0
    return ret
  ret = exec "hostname" 
  if ret != null && ret.length > 0
    return ret
  ret = env.get("HOSTNAME")
  if ret != null && ret.length > 0
    return ret
  else
    return env.get("HOST")
```

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

#### Container/Kubernetes metadata

On Linux, the container ID and some of the Kubernetes metadata can be extracted by parsing `/proc/self/cgroup`. For each line in the file, we split the line according to the format "hierarchy-ID:controller-list:cgroup-path", extracting the "cgroup-path" part. We then attempt to extract information according to the following algorithm:

 1. Split the path into dirname/basename (i.e. on the final slash)

 2. If the basename ends with ".scope", check for a hyphen and remove everything up to and including that. This allows us to match `.../docker-<container-id>.scope` as well as `.../<container-id>`.

 3. Attempt to extract the Kubernetes pod UID from the dirname by matching one of the following regular expressions:
     - `(?:^/kubepods[\\S]*/pod([^/]+)$)`
     - `(?:^/kubepods\.slice/(kubepods-[^/]+\.slice/)?kubepods[^/]*-pod([^/]+)\.slice$)`

    The first capturing group in the first case and the second capturing group in the second case is the pod UID. In the latter case, we must unescape underscores (`_`) to hyphens (`-`) in the pod UID.
    If we match a pod UID then we record the hostname as the pod name since, by default, Kubernetes will set the hostname to the pod name. Finally, we record the basename as the container ID without any further checks.

 4. If we did not match a Kubernetes pod UID above, then we check if the basename matches one of the following regular expressions:

    - `^[[:xdigit:]]{64}$`
    - `^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4,}$`

    If we match, then the basename is assumed to be a container ID.

If the Kubernetes pod name is not the hostname, it can be overridden by the `KUBERNETES_POD_NAME` environment variable, using the [Downward API](https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/). In a similar manner, you can inform the agent of the node name and namespace, using the environment variables `KUBERNETES_NODE_NAME` and `KUBERNETES_NAMESPACE`.

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

### Cloud Provider Metadata

[Cloud provider metadata](https://github.com/elastic/apm-server/blob/master/docs/spec/v2/metadata.json)
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
[the Python agent](https://github.com/elastic/apm-agent-python/blob/master/elasticapm/utils/cloud.py).

#### AWS metadata

[Metadata about an EC2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html) can be retrieved from the internal metadata endpoint, `http://169.254.169.254`.

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

An example with curl

```sh
curl -X GET "http://metadata.google.internal/computeMetadata/v1/?recursive=true" -H "Metadata-Flavor: Google"
```

From the returned metadata, the following fields are useful

| Cloud metadata field  | AWS Metadata field  |
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

An example with curl

```sh
curl -X GET "http://169.254.169.254/metadata/instance/compute?api-version=2019-08-15" -H "Metadata: true"
```

From the returned metadata, the following fields are useful

| Cloud metadata field  | AWS Metadata field  |
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

### Global labels

Events sent by the agents can have labels associated, which may be useful for custom aggregations, or document-level access control. It is possible to add "global labels" to the metadata, which are labels that will be applied to all events sent by an agent. These are only understood by APM Server 7.2 or greater.

Global labels can be specified via the environment variable `ELASTIC_APM_GLOBAL_LABELS`, formatted as a comma-separated list of `key=value` pairs.
