## Database spans

We capture spans for various types of database/data-stores operations, such as SQL queries, Elasticsearch queries, Redis commands, etc. We follow some of the same conventions defined by OpenTracing for capturing database-specific span context, including:

 - `db.instance`: database instance name, e.g. "customers". For DynamoDB, this is the region.
 - `db.statement`: statement/query, e.g. "SELECT * FROM foo"
 - `db.user`: username used for database access, e.g. "readonly_user"
 - `db.type`: database type/category, which should be "sql" for SQL databases, and the lower-cased database name otherwise.

The full database statement should be stored in `db.statement`, which may be useful for debugging performance issues. We store up to 10000 Unicode characters per database statement.

For SQL databases this will be the full SQL statement.

For MongoDB, this can be set to the command encoded as MongoDB Extended JSON.

For Elasticsearch search-type queries, the request body may be recorded. Alternatively, if a query is specified in HTTP query parameters, that may be used instead. If the body is gzip-encoded, the body should be decoded first.

### Database span names

For SQL operations we perform a limited parsing the statement, and extract the operation name and outer-most table involved (if any). See more details here: https://docs.google.com/document/d/1sblkAP1NHqk4MtloUta7tXjDuI_l64sT2ZQ_UFHuytA.

For Redis, the the span name can simply be set to the command name, e.g. `GET` or `LRANGE`.

For MongoDB, the span name should be the command name in the context of its collection/database, e.g. `users.find`.

For Elasticsearch, the span name should be `Elasticsearch: <method> <path>`, e.g.
`Elasticsearch: GET /index/_search`.

### Database span type/subtype

For database spans, the type should be `db` and subtype should be the database name. Agents should standardise on the following span subtypes:

- `postgresql` (PostgreSQL)
- `mysql` (MySQL)