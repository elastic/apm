# Dropping fast exit spans

If an exit span was really fast, chances are that it's not relevant for analyzing latency issues.
Therefore, agents SHOULD implement the strategy laid out in this section to let users choose the level of detail/cost tradeoff that makes sense for them.
If an agent implements this strategy, it MUST also implement [Collecting statistics about dropped spans](tracing-spans-dropped-stats.md).

## `exit_span_min_duration` configuration

Sets the minimum duration of exit spans.
Exit spans with a duration lesser than this threshold are attempted to be discarded.
If the exit span is equal or greater the threshold, it should be kept.

In some cases exit spans cannot be discarded.
For example, spans that propagate the trace context to downstream services,
such as outgoing HTTP requests,
can't be discarded.
However, external calls that don't propagate context,
such as calls to a database, can be discarded using this threshold.

Additionally, spans that lead to an error can't be discarded.

|                |            |
|----------------|------------|
| Type           | [`GranularDuration`](../configuration.md#configuration-value-types) |
| Default        | `1ms`      |
| Central config | `true`     |

## Interplay with span compression

If an agent implements [span compression](tracing-spans-compress.md),
the limit applies to the [composite span](tracing-spans-compress.md#composite-span).

For example, if 10 Redis calls are compressed into a single composite span whose total duration is lower than `exit_span_min_duration`,
it will be dropped.
If, on the other hand, the individual Redis calls are below the threshold,
but the sum of their durations is above it, the composite span will not be dropped.

## Limitations

The limitations are based on the premise that the `parent_id` of each span and transaction that's stored in Elasticsearch
should point to another valid transaction or span that's present in the Elasticsearch index.

A span that refers to a missing span via is `parent_id` is also known as an "orphaned span".

### Spans that propagate context to downstream services can't be discarded

We only know whether to discard after the call has ended.
At that point,
the trace has already continued on the downstream service.
Discarding the span for the external request would orphan the transaction of the downstream call.

Propagating the trace context to downstream services is also known as out-of-process context propagation.

## Implementation

### `discardable` flag

Spans store an additional `discardable` flag in order to determine whether a span can be discarded.
The default value is `true` for [exit spans](../tracing-spans.md#exit-spans) and `false` for any other span.

According to the [limitations](#Limitations),
there are certain situations where the `discardable` flag of a span is set to `false`:
- the span's `outcome` field is set to anything other than `success`.
  So spans with outcome indicating an issue of potential interest are not discardable 
- On out-of-process context propagation

### Determining whether to report a span

If the span's duration is less than `exit_span_min_duration` and the span is discardable (`discardable=true`),
the `span_count.dropped` count is incremented, and the span will not be reported.
We're deliberately using the same dropped counter we also use when dropping spans due to [`transaction_max_spans`](tracing-spans-limit.md#configuration-option-transaction_max_spans).
This ensures that a dropped fast span doesn't consume from the max spans limit.

### Metric collection

To reduce the data loss, agents [collect statistics about dropped spans](tracing-spans-dropped-stats.md).
Dropped spans contribute to [breakdown metrics](https://docs.google.com/document/d/1-_LuC9zhmva0VvLgtI0KcHuLzNztPHbcM0ZdlcPUl64#heading=h.ondan294nbpt) the same way as non-discarded spans.
