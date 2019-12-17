# APM test fixtures

Files provided here may be used by agents to ensure matching results across languages/agents.

## SQL signatures

SQL-based data stores' span names are abbreviated versions of their queries, eg. `SELECT * FROM users WHERE id=1` becomes `SELECT FROM users`.

### For precision

- `tests/sql_token_examples.json`
- `tests/sql_token_examples.json`

To get similar results across agents a set of `input -> expected output` examples are provided here as JSON files.

Using or complying to these isn't a requirement.

- Reference issue: [elastic/apm#12](https://github.com/elastic/apm/issues/12).
- Reference doc: [RFC: SQL parsing](https://docs.google.com/document/d/1sblkAP1NHqk4MtloUta7tXjDuI_l64sT2ZQ_UFHuytA/)

### For performance

- `tests/random_sql_query_set.json`

To test the performance of a given implementation, a dataset of 24,890 unique SQL queries is provided.

These are actual example queries, mostly from the Stack Exchange Data Explorer via [this distribution](https://github.com/johnthebrave/nlidb-datasets). Included is only the original SQL query part as an array with the format `[ { input: 'SELECT *…' }, … ]`.

They are licensed under a [Creative Commons Attribution-ShareAlike 3.0 Unported License](https://creativecommons.org/licenses/by-sa/3.0/).
