[Agent spec home](README.md) > [Handling huge traces](tracing-spans-handling-huge-traces.md) > [Hard limit on number of spans to collect](tracing-spans-limit.md)

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

### Implementation

Before creating a span,
agents must determine whether creating that span would exceed the span limit.
The limit is reached when the total number of created spans minus the number of dropped spans is greater or equals to the max number of spans.
In other words, the limit is reached if this condition is true:

    span_count.total - span_count.dropped >= transaction_max_spans

The `span_count.total` counter is not part of the intake API,
but it helps agents to determine whether the limit has been reached.
It reflects the total amount of started spans within a transaction.

To ensure consistent behavior within one transaction,
the `transaction_max_spans` option should be read once on transaction start.
Even if the option is changed via remote config during the lifetime of a transaction,
the value that has been read at the start of the transaction should be used.

Note that it's not enough to just consider this condition on span start:

    span_count.sent >= transaction_max_spans

That's because there may be any number of concurrent spans that are started but not yet ended.
While the condition could potentially be evaluated on span end,
it's preferable to know at the start of the span whether the span should be dropped.
The reason being that agents can omit heavy operations, such as capturing a request body.

### Metric collection

Even though we can determine whether to drop a span before starting it, it's not legal to return a `null` or noop span in that case.
That's because we're [collecting statistics about dropped spans](tracing-spans-dropped-stats.md) as well as 
[breakdown metrics](https://docs.google.com/document/d/1-_LuC9zhmva0VvLgtI0KcHuLzNztPHbcM0ZdlcPUl64#heading=h.ondan294nbpt)
even for spans that exceed `transaction_max_spans`.
