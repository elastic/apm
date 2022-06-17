
## Table of Contents
* [Database and Datastore spans](#database-and-datastore-spans)
* [Specific Databases](#specific-databases)
  * [AWS DynamoDb](#aws-dynamodb)
  * [AWS S3](#aws-s3)
  * [Elasticsearch](#elasticsearch)
  * [MongoDB](#mongodb)
  * [Redis](#redis)
  * [SQL Databases](#sql-databases)

## Database and Datastore spans

We capture spans for various types of database/data-stores operations, such as SQL queries, Elasticsearch queries, is commands, etc.
Database and datastore spans **must not have child spans that have a different `type` or `subtype`** within the same transaction (see [span-spec](tracing-spans.md)).

The following fields are relevant for database and datastore spans. Where possible, agents should provide information for as many as possible of these fields. The semantics of and concrete values for these fields may vary between different technologies. See sections below for details on specific technologies.

| Field | Description | Mandatory |
|-------|-------------|:---------:|
|`name`| The name of the exit database span. **The span name must have a low cardinality as it is used as a dimension for derived metrics!** Therefore, for SQL operations we perform a limited parsing of the statement, and extract the operation name and outer-most table involved. Other databases and storages may have different strategies for the span name (see specific databases and stores in the sections below).| :white_check_mark: |
|`type`|For database spans, the type should be `db`.| :white_check_mark:|
|`subtype`|For database spans, the subtype should be the database vendor name. See details below for specific databases.| :x: |
|`action`|The database action, e.g. `query`|
| <hr/> |<hr/>|<hr/>|
|`context.db.instance`| Database instance name, e.g. "customers". For DynamoDB, this is the region.| :x: |
|`context.db.statement`| Statement/query, e.g. `SELECT * FROM foo WHERE ...`. The full database statement should be stored in db.statement, which may be useful for debugging performance issues. We store up to 10000 Unicode characters per database statement. For Non-SQL data stores see details below.| :x: |
|`context.db.type`| Database type/category, which should be "sql" for SQL databases, and the lower-cased database name otherwise.| :x: |
|`context.db.user`| Username used for database access, e.g. `readonly_user`| :x: |
|`context.db.link`| Some SQL databases (e.g. Oracle) provide a feature for linking multiple databases to form a single logical database. The DB link differentiates single DBs of a logical database. See https://github.com/elastic/apm/issues/107 for more details. | :x: |
|`context.db.rows_affected`| The number of rows / entities affected by the corresponding db statement / query.| :x: |
| <hr/> |<hr/>|<hr/>|
|`context.destination.address`|The hostname / address of the database.| :x: |
|`context.destination.port`|The port under which the database is accessible.| :x: |
|`context.destination.service.resource`| DEPRECATED, replaced by `service.target.{type,name}` fields | :white_check_mark: mandatory when APM server ignores `service.target.{type,name}`, optional otherwise |
|`context.destination.service.type`| DEPRECATED, replaced by `service.target.{type,name}` fields | :x: |
|`context.destination.service.name`| DEPRECATED, replaced by `service.target.{type,name}` fields | :x: |
|`context.destination.cloud.region`| The cloud region in case the datastore is hosted in a public cloud or is a managed datasatore / database. E.g. AWS regions, such as `us-east-1` | :x: |
| <hr/> |<hr/>|<hr/>|
|`service.target.type`| Defines destination service type, the (`type`,`name`) pair replaces deprecated `context.destination.service.resource` | :white_check_mark:|
|`service.target.name`| Defines destination service name, the (`type`,`name`) pair replaces deprecated `context.destination.service.resource`, for relational databases, the value is equal to `context.db.instance` | :x: |


## Specific Databases

### AWS DynamoDb

| Field | Value / Examples | Comments |
|-------|:---------------:|----------|
|`name`| e.g. `DynamoDB UpdateItem my_table`|  The span name should capture the operation name (as used by AWS for the action name) and the table name, if available. The format should be `DynamoDB <ActionName> <TableName>`. TableName MAY be omitted from the name for operations (`batchWriteItem`, `batchGetItem`, PartiQL-related methods like `executeStatement` etc.) that are acting on more than a single table. If `TableName` is not available, agents SHOULD also check the `TableArn` or `SourceTableArn` query params for a table name and extract the table name from the AWS ARN value.|
|`type`|`db`|
|`subtype`|`dynamodb`|
|`action`| `query` |
| __**context.db._**__ |<hr/>|<hr/>|
|`_.instance`| e.g. `us-east-1` | The AWS region where the table is. |
|`_.statement`| e.g. `ForumName = :name and Subject = :sub` | For a DynamoDB Query operation, capture the KeyConditionExpression in this field. In order to avoid a high cardinality of collected values, agents SHOULD NOT include the full SQL statment for PartiQL-related methods like `executeStatment.|
|`_.type`|`dynamodb`|
|`_.user`| :heavy_minus_sign: |
|`_.link`| :heavy_minus_sign: |
|`_.rows_affected`| :heavy_minus_sign: |
| __**context.destination._**__ |<hr/>|<hr/>|
|`_.address`|e.g. `dynamodb.us-west-2.amazonaws.com`|
|`_.port`|e.g. `5432`|
|`_.service.name`| `dynamodb` | DEPRECATED
|`_.service.type`|`db`| DEPRECATED
|`_.service.resource`| `dynamodb` | DEPRECATED
|`_.cloud.region`| e.g. `us-east-1` | The AWS region where the table is, if available. |
| __**service.target._**__ |<hr/>|<hr/>|
|`_.type`| `dynamodb` ||
|`_.name`| e.g. `us-east-1` | Use same value as `context.db.instance` |

### AWS S3

| Field | Value / Examples | Comments |
|-------|:---------------:|----------|
|`name`| e.g. `S3 GetObject my-bucket`|  The span name should follow this pattern: `S3 <OperationName> <bucket-name>`. Note that the operation name is in PascalCase. |
|`type`|`storage`|
|`subtype`|`s3`|
|`action`| e.g. `GetObject` | The operation name in PascalCase. |
| __**context.db._**__  |<hr/>|<hr/>|
|`_.instance`| e.g. `us-east-1` | The AWS region where the bucket is. |
|`_.statement`| :heavy_minus_sign: |  |
|`_.type`|`s3`|
|`_.user`| :heavy_minus_sign: |
|`_.link`| :heavy_minus_sign: |
|`_.rows_affected`| :heavy_minus_sign: |
| __**context.destination._**__ |<hr/>|<hr/>|
|`_.address`|e.g. `s3.amazonaws.com`| Not available in some cases. Only set if the actual connection is available. |
|`_.port`|e.g. `443`| Not available in some cases. Only set if the actual connection is available. |
|`_.service.name`| `s3` | DEPRECATED, use `service.target.{type,name}`
|`_.service.type`|`storage`| DEPRECATED, use `service.target.{type,name}`
|`_.service.resource`| e.g. `my-bucket`, `accesspoint/myendpointslashes`, or `accesspoint:myendpointcolons`| DEPRECATED, use `service.target.{type,name}` |
|`_.cloud.region`| e.g. `us-east-1` | The AWS region where the bucket is. |
| __**service.target._**__ |<hr/>|<hr/>|
|`_.type`| `s3` ||
|`_.name`| e.g. `my-bucket`, `accesspoint/myendpointslashes`, or `accesspoint:myendpointcolons` | The bucket name, if available. The s3 API allows either the bucket name or an Access Point to be provided when referring to a bucket. Access Points can use either slashes or colons. When an Access Point is provided, the access point name preceded by accesspoint/ or accesspoint: should be extracted. For example, given an Access Point such as `arn:aws:s3:us-west-2:123456789012:accesspoint/myendpointslashes`, the agent extracts `accesspoint/myendpointslashes`. Given an Access Point such as `arn:aws:s3:us-west-2:123456789012:accesspoint:myendpointcolons`, the agent extracts `accesspoint:myendpointcolons`. |

### Elasticsearch

| Span Field | Value / Examples | Comments |
|------------|:----------------:|----------|
|`name`| e.g. `Elasticsearch: GET /index/_search` |  The span name should be `Elasticsearch: <method> <path>` |
|`type`|`db`|
|`subtype`|`elasticsearch`|
|`action`| `request` |
| __**context.db._**__  |<hr/>|<hr/>|
|`_.instance`| :heavy_minus_sign: |
|`_.statement`| e.g. <pre lang="json">{"query": {"match": {"user.id": "kimchy"}}}</pre> | For Elasticsearch search-type queries, the request body may be recorded. Alternatively, if a query is specified in HTTP query parameters, that may be used instead. If the body is gzip-encoded, the body should be decoded first.|
|`_.type`|`elasticsearch`|
|`_.user`| :heavy_minus_sign: |
|`_.link`| :heavy_minus_sign: |
|`_.rows_affected`| :heavy_minus_sign: |
| __**context.destination._**__ |<hr/>|<hr/>|
|`_.address`|e.g. `localhost`|
|`_.port`|e.g. `5432`|
|`_.service.name`| `elasticsearch` | DEPRECATED, use `service.target.{type,name}` |
|`_.service.type`|`db`| DEPRECATED, use `service.target.{type,name}` |
|`_.service.resource`| `elasticsearch` | DEPRECATED, use `service.target.{type,name}` |
| __**context.service.target._**__ |<hr/>|<hr/>|
|`_.type`| `elasticsearch` | |
|`_.name`| :heavy_minus_sign: | |

In addition to [the usual error capture specification](./error-tracking.md), the following apply to errors captured for Elasticsearch client auto-instrumentation.

| Error Field | Value / Examples | Comments |
|-------------|:----------------:|----------|
| `exception.type` | `$exceptionType` or `${exceptionType} (${esResponseBody.error.type})`, e.g. `ResponseError (index_not_found_exception)` | Some Elasticsearch client errors include an error [response body from Elasticsearch with a `error.type`](https://www.elastic.co/guide/en/elasticsearch/reference/current/common-options.html#common-options-error-options). For these errors, the APM agent SHOULD capture that type as in the given example. This helps with error grouping in the APM app. |

### MongoDB

| Field | Value / Examples | Comments |
|-------|:---------------:|----------|
|`name`| e.g. `users.find` |  The name for MongoDB spans should be the command name in the context of its collection/database. |
|`type`|`db`|
|`subtype`|`mongodb`|
|`action`|e.g. `find` , `insert`, etc.| The MongoDB command executed with this action. |
| __**context.db._**__  |<hr/>|<hr/>|
|`_.instance`| :heavy_minus_sign: |
|`_.statement`| e.g. <pre lang="json">find({status: {$in: ["A","D"]}})</pre> | The MongoDB command encoded as MongoDB Extended JSON.|
|`_.type`|`mongodb`|
|`_.user`| :heavy_minus_sign: |
|`_.link`| :heavy_minus_sign: |
|`_.rows_affected`| :heavy_minus_sign: |
| __**context.destination._**__ |<hr/>|<hr/>|
|`_.address`|e.g. `localhost`|
|`_.port`|e.g. `5432`|
|`_.service.name`| `mongodb` | DEPRECATED, use `service.target.{type,name}`  |
|`_.service.type`|`db`| DEPRECATED, use `service.target.{type,name}` |
|`_.service.resource`| `mongodb` | DEPRECATED, use `service.target.{type,name}` |
| __**service.target._**__ |<hr/>|<hr/>|
|`_.type`| `mongob` | |
|`_.name`| :heavy_minus_sign: | |

### Redis

| Field | Value / Examples | Comments |
|-------|:---------------:|----------|
|`name`| e.g. `GET` or `LRANGE` |  The name for Redis spans can simply be set to the command name. |
|`type`|`db`|
|`subtype`|`redis`|
|`action`| `query` |
| __**context.db._**__  |<hr/>|<hr/>|
|`_.instance`| :heavy_minus_sign: |
|`_.statement`|  :heavy_minus_sign: |
|`_.type`|`redis`|
|`_.user`| :heavy_minus_sign: |
|`_.link`| :heavy_minus_sign: |
|`_.rows_affected`| :heavy_minus_sign: |
| __**context.destination._**__ |<hr/>|<hr/>|
|`_.address`|e.g. `localhost`|
|`_.port`|e.g. `5432`|
|`_.service.name`| `redis` |DEPRECATED, use `service.target.{type,name}`  |
|`_.service.type`|`db`|DEPRECATED, use `service.target.{type,name}`  |
|`_.service.resource`| `redis` |DEPRECATED, use `service.target.{type,name}`  |
| __**service.target._**__ |<hr/>|<hr/>|
|`_.type`| `redis` | |
|`_.name`| :heavy_minus_sign: | |

### SQL Databases

| Field | Common values / patterns for all SQL DBs | Comments |
|-------|:---------------:|---------------|
|`name`| e.g. `SELECT FROM products` | For SQL operations we perform a limited parsing the statement, and extract the operation name and outer-most table involved (if any). See more details [here](https://docs.google.com/document/d/1sblkAP1NHqk4MtloUta7tXjDuI_l64sT2ZQ_UFHuytA). |
|`type`|`db`|
|`subtype`| e.g. `oracle`, `mysql` | [see below](#database-subtype) |
|`action`|`query`|
| __**context.db._**__  |<hr/>|<hr/>|
|`_.instance`| e.g. `instance-name`| [see below](#database-instance) |
|`_.statement`| e.g. `SELECT * FROM products WHERE ...`| The full SQL statement. We store up to 10000 Unicode characters per database statement.  |
|`_.type`|`sql`|
|`_.user`| e.g. `readonly_user`|
|`_.rows_affected`| e.g. `123`|
| __**context.destination._**__ |<hr/>|<hr/>|
|`_.address`|e.g. `localhost`|
|`_.port`|e.g. `5432`|
|`_.service.type`|`db`| DEPRECATED, use `service.target.{type,name}`  |
|`_.service.resource`| |DEPRECATED, use `service.target.{type,name}`  |
| __**service.target._**__ |<hr/>|<hr/>|
|`_.type`| e.g. `mysql` | Same value as `subtype` |
|`_.name`|  | Database name, same as `db.instance` if available  |

#### Database subtype

| Database name        | `subtype`   |
|:---------------------|:-----------:|
| MySQL                | `mysql`     |
| MariaDB              | `mariadb`   |
| PostgreSQL           | `postgresql`|
| Microsoft SQL server | `sqlserver` |
| Oracle               | `oracle`    |
| IBM Db2              | `db2`       |

#### Database instance

For most relational databases, the value of `db.instance` should map to the concept of "current database".
When no database selected, for example when creating a database, this field should be omitted.

While the semantics may vary across vendors, the goal here is to have a single string that can be used for correlation,
it is thus important to be able to get the same value across all agents.

There are multiple ways to capture it, agents SHOULD attempt to capture it with the following priorities:
1. Parsing the database connection string: parsing can be complex, no runtime impact,
2. Querying connection metadata at runtime: acceptable as fallback, might trigger extra SQL queries, require caching to minimize overhead

For most databases, the `database` parameter of the connection string should be available. For those that implement the [`INFORMATION_SCHEMA`](https://en.wikipedia.org/wiki/Information_schema) standard, it should be included in the values returned by `SELECT schema_name FROM information_schema.schemata`;

**Oracle** : Use instance as defined in [Oracle DB instances](https://docs.oracle.com/cd/E11882_01/server.112/e40540/startup.htm#CNCPT005), the instance name should be the same as retrieved through `SELECT sys_context('USERENV','INSTANCE_NAME') AS Instance`. When multiple identifiers are available, the following priotity should be applied (first available wins): `INSTANCE_NAME`, `SERVICE_NAME`, `SID`.

**MS SQL** : Use instance as defined in [MS SQL instances](https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/database-engine-instances-sql-server?view=sql-server-ver15)
