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

Services running on AWS Lambda [require specific values](tracing-instrumentation-aws-lambda.md) for some of the above mentioned fields.

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

Fetching of cloud metadata for services running as AWS Lambda functions follow a [different approach defined in the tracing-instrumentation-aws-lambda spec](tracing-instrumentation-aws-lambda.md).

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
