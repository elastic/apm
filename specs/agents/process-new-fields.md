# Process for adding new fields

If an agent dev wants to show new data they write a proposal for how it should be stored in the context.
They should not add it to tags or custom.
We can’t have agents just add data as they see fit because then it won’t be aligned,
it will move around if they change their mind etc.,
that would break peoples assumptions about where it is and if they add to tags,
it would create new fields in the index and then stop using it when we standardize

* The proposal should specify how the data fits into a top level key under `context` in the Intake API and how it fits in the Elasticsearch events that get written by APM Server.
For example `context.elasticsearch.url` in the intake API becomes `elasticsearch.url` in Elasticsearch, `context.elasticsearch.error_reason` becomes `elasticsearch.error_reason` etc.
* The proposal needs to specify which fields should be indexed.
An APM Server person might need to assist here to determine the right data type for the indexed fields.
* The proposal should include the suggested [JSON Schema](https://github.com/elastic/apm-server/tree/main/docs/spec/v2) changes for all new fields.
This forces alignment on the exact field names, JSON data type, length restrictions etc.
* Make sure to check if [ECS](https://github.com/elastic/ecs) has defined appropriate fields for what you're proposing.
* Agents should agree to the changes in a voting format (checkboxes),
once they agree an issue should be created on the agent,
apm-server and/or kibana repos to track the implementation.
Once we have issues for all the implementations, the original one can be closed.
* As soon as the JSON Schema changes have been merged into APM Server,
agents can implement and test their implementation against the new schema.
It is typically only a matter of a few hours to implement new fields in APM Server once the details are agreed upon.
* Agent devs can release new versions that send the new fields as soon the changes are merged into APM Server.
APM Server will not reject arbitrary fields in `context`, but fields that are not defined in APM Server are not stored, indexed or validated.
When users upgrade their stack, the new fields will start to appear.
* The UI will show every field under the existing top-level fields. E.g. everything under `request` shows up in the UI automatically. If we add a new top level fields, the UI also needs to get updated.
* When we add data to the span context or transaction context,
this data should also be allowed in the error context and arbitrary data in the error context should be shown, just like for spans and transactions.
That way, when an error happens, we can supply the context in the error context directly.
We have previously decided that we need an error context and that it's not enough to just link errors to their parent span.
* Errors that are captured in instrumentations should include/copy all the contextual data that would go on that span into the error context


Example:

1. We have built an Elasticsearch instrumentation that gets some useful context: `elasticsearch.url`, `elasticsearch.response_code`, `elasticsearch.error_reason`.
2. Agent dev opens a proposal that looks like this:

**Proposal:**

Add optional fields to
- [x] _span context_
- [ ] _transaction context_

as always, this should also be added to the _error context_.

| Intake API field | Elasticsearch field | Elasticsearch Type |
| -----------------|-------------------------|---------------------|
| `context.elasticsearch.url` | `elasticsearch.url` | not indexed |
| `context.elasticsearch.response_code` | `elasticsearch.response_code` | indexed as keyword |
| `context.elasticsearch.error_reason` | `elasticsearch.error_reason` | not indexed |
| `context.elasticsearch.cluster_name` | `elasticsearch.cluster_name` | not indexed |


JSON Schema:
```json
{
  "url": {
    "type": ["string"]
  },
  "response_code": {
    "type": ["string"],
    "maxLength": 1024
  },
  "error_reason": {
    "type": ["string"],
    "maxLength": 10000
  },
  "cluster_name": {
    "type": ["string"],
  }
}
```
Not all agents will send `context.elasticsearch.cluster_name`. This is _fine_. We should still align on the ones we can.

Note: As this is a new top level field, the UI needs an update.

Agents OK with this change:

- [ ] @elastic/apm-ui (if this is a new top level field)
- [ ] RUM
- [ ] Node.js
- [ ] Java
- [ ] ...

1. When agent devs and APM Server agree, APM Server implements the changes necessary
1. When merged into `main`, agent devs can implement the fields immediately.
The agent tests against APM Server `main` now tests the integration with the new fields in the JSON Schema.
1. Agents can release when their test are green. Next APM Server release will include the changes,
which might include indexing some new fields.
