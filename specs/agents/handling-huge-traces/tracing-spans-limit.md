# Hard limit on number of spans to collect

This is the last line of defense that comes with the highest amount of data loss.
This strategy MUST be implemented by all agents.
Ideally, the other mechanisms limit the amount of spans enough so that the hard limit does not kick in.

Agents SHOULD also [collect statistics about dropped spans](tracing-spans-dropped-stats.md) when implementing this spec.

## Configuration option `transaction_max_spans`

Limits the amount of spans that are recorded per transaction.

This is helpful in cases where a transaction creates a very high amount of spans (e.g. thousands of SQL queries).

Setting an upper limit will prevent overloading the agent and the APM server with too much work for such edge cases.

|                |          |
|----------------|----------|
| Type           | `integer`|
| Default        | `500`    |
| Dynamic        | `true`   |

## Implementation

### Span count

When a span is put in the agent's reporter queue, a counter should be incremented on its transaction, in order to later identify the _expected_ number of spans.
In this way we can identify data loss, e.g. because events have been dropped.

This counter SHOULD internally be named `reported` and MUST be mapped to `span_count.started` in the intake API.
The word `started` is a misnomer but needs to be used for backward compatibility.
The rest of the spec will refer to this field as `span_count.reported`.

When a span is dropped, it is not reported to the APM Server,
instead another counter is incremented to track the number of spans dropped.
In this case the above mentioned counter for `reported` spans is not incremented.

```json
"span_count": {
  "started": 500,
  "dropped": 42
}
```

The total number of spans that an agent created within a transaction is equal to `span_count.started + span_count.dropped`.
Note that this might be an under count, because spans that end *after* their
transaction has been reported (typically when the transaction ends) will not be
counted.

### Checking the limit

Before creating a span,
agents must determine whether that span would exceed the span limit.
The limit is reached when the number of reported spans is greater or equal to the max number of spans.
In other words, the limit is reached if this condition is true:

    atomic_get(transaction.span_count.eligible_for_reporting) >= transaction_max_spans

On span end, agents that support the concurrent creation of spans need to check the condition again.
That is because any number of spans may be started before any of them end.

```java
if (atomic_get(transaction.span_count.eligible_for_reporting) <= transaction_max_spans // optional optimization
    && atomic_get_and_increment(transaction.span_count.eligible_for_reporting) <= transaction_max_spans ) {
    should_be_reported = true
    atomic_increment(transaction.span_count.reported)
} else {
    should_be_reported = false
    atomic_increment(transaction.span_count.dropped)
    transaction.track_dropped_stats(this)
}
```

`eligible_for_reporting` is another counter in the span_count object, but it's not reported to APM Server.
It's similar to `reported` but the value may be higher.

### Configuration snapshot

To ensure consistent behavior within one transaction,
the `transaction_max_spans` option should be read once on transaction start.
Even if the option is changed via remote config during the lifetime of a transaction,
the value that has been read at the start of the transaction should be used.

### Metric collection

Even though we can determine whether to drop a span before starting it, it's not legal to return a `null` or noop span in that case.
That's because we're [collecting statistics about dropped spans](tracing-spans-dropped-stats.md) as well as
[breakdown metrics](https://docs.google.com/document/d/1-_LuC9zhmva0VvLgtI0KcHuLzNztPHbcM0ZdlcPUl64#heading=h.ondan294nbpt)
even for spans that exceed `transaction_max_spans`.

For spans that are known to be dropped upfront, Agents SHOULD NOT collect information that is expensive to get and not needed for metrics collection.
This includes capturing headers, request bodies, and summarizing SQL statements, for example.
