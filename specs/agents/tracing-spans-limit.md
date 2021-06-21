## Hard limit on number of spans to collect

This is the last line of defense that comes with the highest amount of data loss.
This strategy MUST be implemented by all agents.
Ideally, the other mechanisms limit the amount of spans enough so that the hard limit does not kick in.

### Configuration option `transaction_max_spans`

Limits the amount of spans that are recorded per transaction.

This is helpful in cases where a transaction creates a very high amount of spans (e.g. thousands of SQL queries).

Setting an upper limit will prevent overloading the agent and the APM server with too much work for such edge cases.

|                |          |
|----------------|----------|
| Type           | `integer`|
| Default        | `500`    |
| Dynamic        | `true`   |
