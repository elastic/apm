# Azure services spans

We describe how to instrument some of Azure's services in this document.
Some of the services can use existing specs. When there are differences or additions, they have been noted below.


----

**NOTE**: 
Azure Storage can be run as part of [Azure Stack](https://azure.microsoft.com/en-au/overview/azure-stack/). Azure services cannot be inferred from Azure Stack HTTP service endpoints.

----

## Azure Storage

Azure Storage is a collection of storage services, accessed through a
Storage account. The services include

- Blob storage
- Queue storage
- File share storage
- Table storage

A storage account is created in an Azure location (_region_), but the
location is not discoverable through REST API calls.

### Blob storage

Object storage for binary and text data via a REST API. There are three types of blobs: block blobs, page blobs and append blobs.

Blobs are organized into containers, where a container can contain an
unlimited number of blobs, and a storage account can contain an unlimited
number of containers. Although blob storage is a flat storage scheme
(only one level of containers), blob names can include path segments (`/`),
providing a _virtual_ hierarchy.

A resource name is the full name of the container and blob. For example, Given container `foo` and blob `bar/baz`, the resource name
is `foo/bar/baz`.

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `span.name` | yes | `AzureBlob <OperationName> <ResourceName>` | Pascal case Operation name | `AzureBlob Upload foo/bar/baz` |
| `span.type` | yes | `storage` | | |
| `span.subtype` | yes | `azureblob` | | |
| `span.action` | yes | `<OperationName>` | Pascal case | `Upload` |

#### Span context fields

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `context.destination.address` | yes | URL scheme and host | | `https://accountname.blob.core.windows.net/` |
| `context.destination.service.name` | yes | `azureblob` | | | 
| `context.destination.service.resource` | yes | `azureblob/<ResourceName>` | | `azureblob/foo/bar` |
| `context.destination.service.type` | yes | `storage` | | | 


#### Determining operations

There are [_many_ blob storage operations](https://docs.microsoft.com/en-us/rest/api/storageservices/operations-on-blobs).

Azure service endpoints for blob storage have one of the following host names

| Cloud | Azure Service Endpoint |
| ----- | ---------------------- |
| Azure Global | `<account>.blob.core.windows.net` |
| [Azure Government](https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-developer-guide) | `<account>.blob.core.usgovcloudapi.net` |
| [Azure China](https://docs.microsoft.com/en-us/azure/china/resources-developer-guide) |`<account>.blob.core.chinacloudapi.cn` |
| [Azure Germany](https://docs.microsoft.com/en-us/azure/germany/germany-developer-guide) | `<account>.blob.core.cloudapi.de` |

where `<account>` is the name of the storage account. New Azure service endpoints may be introduced by Azure later.

Rules derived from the [Blob service REST API reference](https://docs.microsoft.com/en-us/rest/api/storageservices/blob-service-rest-api). The rules determine the operation name based
on the presence of data in the HTTP request

| HTTP verb | HTTP headers | HTTP query string | Resulting Operation Name |
| --------- | ---------- | ------------------- | ------------------------ |
| DELETE    |                                         | | Delete          |
| GET       | | `restype=container`                     | GetProperties   |
| GET       | | `comp=metadata`                         | GetMetadata     |
| GET       | | `restype=container` and `comp=acl`      | GetAcl          |
| GET       | | `restype=container` and `comp=list`     | ListBlobs       |
| GET       | | `comp=list`                             | ListContainers  |
| GET       | | `comp=tags`                             | GetTags         |
| GET       | | `comp=tags` and `where=<expression>`    | FindTags        |
| GET       | | `comp=blocklist`                        | Download        |
| GET       |                                         | | Download        |
| GET       | | `comp=pagelist`                         | GetPageRanges   |
| HEAD      | |                                         | GetProperties   |
| HEAD      | | `restype=container` and `comp=metadata` | GetMetadata     |
| HEAD      | | `restype=container` and `comp=acl`      | GetAcl          |
| POST      | | `comp=batch`                            | Batch           |
| POST      | | `comp=query`                            | Query           |
| PUT       | `x-ms-copy-source`                      | | Copy            |
| PUT       | `x-ms-copy-source` | `comp=block`         | Copy            |
| PUT       | `x-ms-copy-source` | `comp=page`          | Copy            |
| PUT       | `x-ms-copy-source` | `comp=incrementalcopy` | Copy          |
| PUT       | `x-ms-copy-source` | `comp=appendblock`   | Copy            |
| PUT       | | `comp=copy`                             | Abort           |
| PUT       | `x-ms-blob-type`                        | |  Upload         |
| PUT       | | `comp=block`                            |  Upload         |
| PUT       | | `comp=blocklist`                        |  Upload         |
| PUT       | | `comp=page`                             |  Upload         |
| PUT       | | `comp=appendblock`                      |  Upload         |
| PUT       |                                         | | Create          |
| PUT       | | `comp=metadata`                         | SetMetadata     |
| PUT       | | `restype=container` and `comp=acl`      | SetAcl          |
| PUT       | | `comp=properties`                       | SetProperties   |
| PUT       | | `comp=lease`                            | Lease           |
| PUT       | | `comp=snapshot`                         | Snapshot        |
| PUT       | | `comp=undelete`                         | Undelete        |
| PUT       | | `comp=tags`                             | SetTags         |
| PUT       | | `comp=tier`                             | SetTier         |
| PUT       | | `comp=expiry`                           | SetExpiry       |

### Queue storage

Queue storage allows sending and receiving messages that may be read by any 
client who has access to the storage account. Messages are sent to and received from queues.

The [messaging spec](tracing-instrumentation-messaging.md) can 
be used for instrumenting Queue storage, with the following additions superseding the messaging spec.

A new span is created when there is a current transaction, and when a message is sent to a queue

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `span.name` | yes | `AzureQueue <OperationName> to <QueueName>` | Upper case Operation name | `AzureQueue SEND to queuename` |
| `span.type` | yes | `messaging` | | |
| `span.subtype` | yes | `azurequeue` | | |
| `span.action` | yes | `<OperationName>` | lower case | `send` |

#### Span context fields

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `context.destination.address` | yes | URL scheme and host | | `https://accountname.queue.core.windows.net/` |
| `context.destination.service.name` | yes | `azurequeue` | | | 
| `context.destination.service.resource` | yes | `azurequeue/<QueueName>` | | `azurequeue/queuename` |
| `context.destination.service.type` | yes | `messaging` | | | 

----

A new transaction is created when one or more messages are received from a queue

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `transaction.name` | yes | `AzureQueue <OperationName> from <QueueName>` | Upper case Operation name | `AzureQueue RECEIVE from queuename` |
| `transaction.type` | yes | `messaging` | | |


#### Transaction context fields

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `context.service.framework` | yes | `AzureQueue` | |  |

#### Determining operations

Azure service endpoints for queue storage have one of the following host names

| Cloud | Azure Service Endpoint |
| ----- | ---------------------- |
| Azure Global | `<account>.queue.core.windows.net` |
| [Azure Government](https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-developer-guide) | `<account>.queue.core.usgovcloudapi.net` |
| [Azure China](https://docs.microsoft.com/en-us/azure/china/resources-developer-guide) |`<account>.queue.core.chinacloudapi.cn` |
| [Azure Germany](https://docs.microsoft.com/en-us/azure/germany/germany-developer-guide) | `<account>.queue.core.cloudapi.de` |

where `<account>` is the name of the storage account. New Azure service endpoints may be introduced by Azure later.

Rules derived from the [Queue service REST API reference](https://docs.microsoft.com/en-us/rest/api/storageservices/queue-service-rest-api)

| URL | HTTP verb | HTTP headers | HTTP query string | Resulting Operation Name |
| --- | --------- | ---------- | ------------------- | ------------------------ |
| | DELETE    |            |                     | DELETE                   |
| ends with /messages | DELETE    |            |                     | CLEAR                   |
| | DELETE    |            | `popreceipt=<value>`| DELETE                   |
| | GET       |            | `comp=list`         | LISTQUEUES               |
| | GET       |            | `comp=properties`   | GETPROPERTIES            |
| | GET       |            | `comp=stats`        | STATS                    |
| | GET       |            | `comp=metadata`     | GETMETADATA              |
| | GET       |            | `comp=acl`          | GETACL                   |
| | GET       |            |                     | RECEIVE                  |
| | GET       |            | `peekonly=true`     | PEEK                     |
| | HEAD      |            | `comp=metadata`     | GETMETADATA              |
| | HEAD      |            | `comp=acl`          | GETACL                   |
| | OPTIONS   |            |                     | PREFLIGHT                |
| | POST      |            |                     | SEND                     |
| | PUT       |            | `comp=acl`          | SETACL                   |
| | PUT       |            | `comp=properties`   | SETPROPERTIES            |
| | PUT       |            |                     | CREATE                   |
| | PUT       |            | `comp=metadata`     | SETMETADATA              |
| | PUT       |            | `popreceipt=<value>`| UPDATE                   |

### Table storage

The Table service offers non-relational schema-less structured storage in the 
form of tables. It is a popular service due to its cost-to-capability, though
messaging in recent years from Microsoft has deprecated Table storage and encouraged
the use of CosmosDB and its Table storage compatible API.

Tables store data as a collection of entities, where an entity is a collection of properties.
Entities are similar to rows and properties are similar to columns.

`<ResourceName>` is the name of the resource in the form of the table, or the table and partition key and row key of an entity. For example,

- tablename
- tablename(PartitionKey='partitionkey', RowKey='rowkey')

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `span.name` | yes | `AzureTable <OperationName> <ResourceName>` | Pascal case Operation name | `AzureTable Insert tablename` |
| `span.type` | yes | `storage` | | |
| `span.subtype` | yes | `azuretable` | | |
| `span.action` | yes | `<OperationName>` | Pascal case | `Insert` |

#### Span context fields

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `context.destination.address` | yes | URL scheme and host | | `https://accountname.table.core.windows.net/` |
| `context.destination.service.name` | yes | `azuretable` | | | 
| `context.destination.service.resource` | yes | `azuretable/<ResourceName>` | | `azuretable/foo` |
| `context.destination.service.type` | yes | `storage` | | |

#### Determining operations

Azure service endpoints for table storage have one of the following host names

| Cloud | Azure Service Endpoint |
| ----- | ---------------------- |
| Azure Global | `<account>.table.core.windows.net` |
| [Azure Government](https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-developer-guide) | `<account>.table.core.usgovcloudapi.net` |
| [Azure China](https://docs.microsoft.com/en-us/azure/china/resources-developer-guide) |`<account>.table.core.chinacloudapi.cn` |
| [Azure Germany](https://docs.microsoft.com/en-us/azure/germany/germany-developer-guide) | `<account>.table.core.cloudapi.de` |

where `<account>` is the name of the storage account. New Azure service endpoints may be introduced by Azure later.

Rules derived from the [Table service REST API reference](https://docs.microsoft.com/en-us/rest/api/storageservices/table-service-rest-api)

| URL | HTTP verb | HTTP headers | HTTP query string | Resulting Operation Name |
| --- | --------- | ---------- | ------------------- | ------------------------ |
| | PUT    |            |   `comp=properties`                  | SetProperties    |
| | GET    |            |   `comp=properties`                  | GetProperties    |
| | GET    |            |   `comp=stats`                       | Stats            |
| ends with /Tables | GET    |            |                  | Query           |
| ends with /Tables | POST    |            |                 | Create           |
| ends with /Tables('`<table>`') | DELETE    |            |  | Delete           |
| ends with /`<table>` | OPTIONS    |            |           | Preflight        |
| | HEAD      |            | `comp=acl`          | GetAcl                   |
| | GET      |            | `comp=acl`          | GetAcl                   |
| | PUT      |            | `comp=acl`          | SetAcl                   |
| ends with /`<table>`() or /`<table>`(PartitionKey='`<partition-key>`',RowKey='`<row-key>`')`  | GET    |            |                  | Query            |
| ends with /`<table>` | POST      |            |           | Insert                   |
| ends with /`<table>`(PartitionKey='`<partition-key>`',RowKey='`<row-key>`')` | PUT      |            |           | Update                   |
| ends with /`<table>`(PartitionKey='`<partition-key>`',RowKey='`<row-key>`')` | MERGE      |            |           | Merge                   |
| ends with /`<table>`(PartitionKey='`<partition-key>`',RowKey='`<row-key>`')` | DELETE      |            |           | Delete                   |

### File share storage

Azure file service (known also as AFS or file share storage) is a managed file share service
that uses Server Message Block (SMB) protocol or Network File System (NFS) protocol
to provide general purpose file shares. File shares can be mounted concurrently by
machines in the cloud or on-premises.

The `<ResourceName>` is determined from the path of the URL.

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `span.name` | yes | `AzureFile <OperationName> <ResourceName>` | Pascal case Operation name | `AzureFile Create directoryname` |
| `span.type` | yes | `storage` | | |
| `span.subtype` | yes | `azurefile` | | |
| `span.action` | yes | `<OperationName>` | Pascal case | `Insert` |

#### Span context fields

| APM field | Required? | Format | Notes | Example |
| --------- | --------- | ------ | ----- | ------- |
| `context.destination.address` | yes | URL scheme and host | | `https://accountname.file.core.windows.net/` |
| `context.destination.service.name` | yes | `azurefile` | | | 
| `context.destination.service.resource` | yes | `azurefile/<ResourceName>` | | `azurefile/foo` |
| `context.destination.service.type` | yes | `storage` | | |

#### Determining operations

Azure service endpoints for file share storage have one of the following host names

| Cloud | Azure Service Endpoint |
| ----- | ---------------------- |
| Azure Global | `<account>.file.core.windows.net` |
| [Azure Government](https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-developer-guide) | `<account>.file.core.usgovcloudapi.net` |
| [Azure China](https://docs.microsoft.com/en-us/azure/china/resources-developer-guide) |`<account>.file.core.chinacloudapi.cn` |
| [Azure Germany](https://docs.microsoft.com/en-us/azure/germany/germany-developer-guide) | `<account>.table.file.cloudapi.de` |

where `<account>` is the name of the storage account. New Azure service endpoints may be introduced by Azure later.

Rules derived from the [File service REST API reference](https://docs.microsoft.com/en-us/rest/api/storageservices/file-service-rest-api).

| URL | HTTP verb | HTTP headers | HTTP query string | Resulting Operation Name |
| --- | --------- | ---------- | ------------------- | ------------------------ |
| | GET    |            |   `comp=list`                  | List    |
| | GET    |            |   `comp=list`                  | List    |
| | PUT    |            |   `comp=properties`                  | SetProperties    |
| | GET    |            |   `comp=properties`                  | GetProperties    |
| ends with /`<resource>` | OPTIONS    |            |           | Preflight        |
| | PUT    |            |                   | Create    |
| | PUT    |            |   `comp=snapshot`                | Snapshot    |
| | PUT    |            |   `restype=share` and `comp=properties` | SetProperties    |
| | GET    |            |   `restype=share`                  | GetProperties    |
| | HEAD    |            |   `restype=share`                  | GetProperties    |
| | GET    |            |   `comp=metadata`                  | GetMetadata    |
| | HEAD    |            |   `comp=metadata`                  | GetMetadata    |
| | PUT    |            |   `comp=metadata`                  | SetMetadata    |
| | DELETE    |            |                | Delete    |
| | PUT    |            |  `comp=undelete`              | Undelete    |
| | HEAD      |            | `comp=acl`          | GetAcl                   |
| | GET      |            | `comp=acl`          | GetAcl                   |
| | PUT      |            | `comp=acl`          | SetAcl                   |
| | GET    |            |   `comp=stats`                       | Stats            |
| | GET    |            |   `comp=filepermission`                       | GetPermission            |
| | PUT    |            |   `comp=filepermission`                       |SetPermission            |
| | PUT    |            |  `restype=directory`                 | Create    |
| | GET    |            |  `comp=listhandles`                 | ListHandles    |
| | PUT    |            |  `comp=forceclosehandles`                 | CloseHandles    |
| | GET    |            |                  | Download    |
| | HEAD    |            |                  | GetProperties    |
| | PUT    |            |   `comp=range` | Upload    |
| | PUT    | `x-ms-copy-source`           |   | Copy    |
| | PUT    | `x-ms-copy-action:abort`           | `comp=copy`  | Abort    |
| | GET    |  |   `comp=rangelist` | ListRanges    |
| | PUT    |            |  `comp=lease`                 | Lease    |


## Azure Service Bus

Azure Service Bus is a message broker service. The [messaging spec](tracing-instrumentation-messaging.md) can 
be used for instrumenting Azure Service Bus, but the follow specifications supersede those of the messaging spec.

Azure Service Bus can use the following protocols 

- Advanced Message Queuing Protocol 1.0 (AMQP)
- Hypertext Transfer Protocol 1.1 with TLS (HTTPS)

The offical Azure SDKs generally use AMQP for sending and receiving messages.

### Typing

- Spans: 
  - `span.subtype`: `azureservicebus` 

### Additional actions

Azure Service Bus supports actions that should be traced in addition to `SEND` and `RECEIVE`:

- `SCHEDULE`

  Message published to the bus, but not visible until some later point.

- `RECEIVEDEFERRED`

  Message received from the bus, but marked as deferred on the bus, then later retrieved with receive deferred.

### Naming

Messages can be sent to queues and topics, and can be received from queues and topic subscriptions.

Transaction and span names *should* follow these patterns:

For send and schedule,

- AzureServiceBus SEND|SCHEDULE to `<queue>`|`<topic>`

For receive and receive deferred,

- AzureServiceBus RECEIVE|RECEIVEDEFERRED from `<queue>`|`<topic>`/Subscriptions/`<subscription>`
