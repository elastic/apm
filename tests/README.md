# APM test fixtures

Files provided here may be used by agents to ensure matching results across languages/agents.

## SQL signatures

SQL-based data stores' span names are abbreviated versions of their queries, eg. `SELECT * FROM users WHERE id=1` becomes `SELECT FROM users`.

To get similar results across agents a set of `input -> expected output` examples are provided here as JSON files.

Using or complying to these isn't a requirement.

- Reference issue: [elastic/apm#12](https://github.com/elastic/apm/issues/12).
- Reference doc: [RFC: SQL parsing](https://docs.google.com/document/d/1sblkAP1NHqk4MtloUta7tXjDuI_l64sT2ZQ_UFHuytA/)
