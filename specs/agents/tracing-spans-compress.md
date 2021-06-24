## Compressing spans

To mitigate the potential flood of spans to a backend,
agents SHOULD implement the strategies laid out in this section to avoid sending almost identical and very similar spans.

While compressing multiple similar spans into a single composite span can't fully eliminate the collection overhead,
it can significantly reduce the impact on the following areas,
with very little loss of information.
- Agent reporter queue utilization
- Capturing stack traces, serialization, compression, and sending events to APM Server
- Potential to re-use span objects, significantly reducing allocations
- Downstream effects like reducing impact on APM Server, ES storage, and UI performance


### Consecutive-Exact-Match compression strategy

One of the biggest sources of excessive data collection are n+1 type queries and repetitive requests to a cache server.
This strategy detects consecutive spans that hold the same information (except for the duration)
and creates a single [composite span](tracing-spans-compress.md#composite-span).

```
[                              ]
GET /users
 [] [] [] [] [] [] [] [] [] []
 10x SELECT FROM users
```

Two spans are considered to be an exact match if they are of the [same kind](consecutive-same-kind-compression-strategy) and if their span names are equal:
- `type`
- `subtype`
- `destination.service.resource`
- `name`

### Consecutive-Same-Kind compression strategy

Another pattern that often occurs is a high amount of alternating queries to the same backend.
Especially if the individual spans are quite fast, recording every single query is likely to not be worth the overhead.

```
[                              ]
GET /users
 [] [] [] [] [] [] [] [] [] []
 10x Calls to mysql
```

Two spans are considered to be of the same type if the following properties are equal:
- `type`
- `subtype`
- `destination.service.resource`

```java
boolean isSameKind(Span other) {
    return type == other.type
        && subtype == other.subtype
        && destination.service.resource == other.destination.service.resource
}
```

When applying this compression strategy, the `span.name` is set to `Calls to $span.destination.service.resource`.
The rest of the context, such as the `db.statement` will be determined by the first compressed span, which is turned into a composite span.


#### Configuration option `same_kind_compression_max_duration`

Consecutive spans to the same destination that are under this threshold will be compressed into a single composite span.
This reduces the collection, processing, and storage overhead, and removes clutter from the UI.
The tradeoff is that the statement information will not be collected. 

|                |          |
|----------------|----------|
| Type           | `duration`|
| Default        | `5ms`    |
| Dynamic        | `true`   |

### Composite span

Compressed spans don't have a physical span document.
Instead, multiple compressed spans are represented by a composite span.

#### Data model

The `timestamp` and `duration` have slightly similar semantics,
and they define properties under the `composite` context.

- `timestamp`: The start timestamp of the first span.
- `duration`: The sum of durations of all spans.
- `composite`
    - `count`: The number of compressed spans this composite span represents.
      The minimum count is 2 as a composite span represents at least two spans.
    - `end`: The end timestamp of the last compressed span.
      The net duration of all compressed spans is equal to the composite spans' `duration`.
      The gross duration (including "whitespace" between the spans) is equal to `compressed.end - timestamp`.
    - `exact_match`: A boolean flag indicating whether the
      [Consecutive-Same-Kind compression strategy](tracing-spans-compress.md#consecutive-same-kind-compression-strategy) (`false`) or the
      [Consecutive-Exact-Match compression strategy](tracing-spans-compress.md#consecutive-exact-match-compression-strategy) (`true`) has been applied.

#### Turning compressed spans into a composite span

Spans have a `compress` method.
The first time `compress` is called on a regular span, it becomes a composite span,
incorporating the new span by updating the count and end timestamp.

```java
void compress(Span other, boolean exactMatch) {
    if (compressed.count == 0) {
        compressed.count = 2
    } else {
        compressedCount++
    }
    compressed.exactMatch = compressed.exactMatch && exactMatch
    endTimestamp = max(endTimestamp, other.endTimestamp)
}
```

#### Effects on metric processing

As laid out in the [span destination spec](tracing-spans-destination.md#contextdestinationserviceresource),
APM Server tracks span destination metrics.
To avoid compressed spans to skew latency metrics and cause throughput metrics to be under-counted,
APM Server will take `composite.count` into account when tracking span destination metrics.

### Compression algorithm

#### Eligibility for compression

A span is eligible for compression if all the following conditions are met
- It's an [exit span](https://github.com/elastic/apm/blob/master/specs/agents/tracing-spans-destination.md#contextdestinationserviceresource)
- The trace context of this span has not been propagated to a downstream service

The latter condition is important so that we don't remove (compress) a span that may be the parent of a downstream service.
This would orphan the sub-graph started by the downstream service and cause it to not appear in the waterfall view.

```java
boolean isCompressionEligible() {
    return exit && !context.hasPropagated
}
```

#### Span buffering

Non-compression-eligible spans may be reported immediately after they have ended.
When a compression-eligible span ends, it does not immediately get reported.
Instead, the span is buffered within its parent.
A span/transaction can buffer at most one child span.

Span buffering allows to "look back" one span when determining whether a given span should be compressed.

A buffered span gets reported when
1. its parent ends
2. a non-compressible sibling ends

```java
void onSpanEnd() {
    if (isCompressionEligible()) {
        if (parent.hasBufferedSpan()) {
            parent.tryCompress(this)
        } else {
            parent.buffered = this
        }
    } else { 
        report(buffered)
        report(this)
    }
}
```

#### Compression

On span end, we compare each [compression-eligible](tracing-spans-compress.md#eligibility-for-compression) span to it's previous sibling.

If the spans are of the same kind but have different span names and the compressions-eligible span's `duration` <= `same_kind_compression_max_duration`,
we compress them using the [Consecutive-Same-Kind compression strategy](tracing-spans-compress.md#consecutive-same-kind-compression-strategy).

If the spans are of the same kind, and have the same name,
we apply the [Consecutive-Exact-Match compression strategy](tracing-spans-compress.md#consecutive-exact-match-compression-strategy).

```java
void tryCompress(Span child) {
    if (buffered.isSameKind(child)) {
        if (buffered.name == child.name) {
            buffered.compress(child, exactMatch: true)
            return
        } else if ( (buffered.duration <= same_kind_compression_max_duration || buffered.composite.count > 1)
                   && child.duration <= same_kind_compression_max_duration) {
            buffered.name = "Calls to $buffered.destination.service.resource"
            buffered.compress(child, exactMatch: false)
            return
        }
    }
    report(buffered)
    buffered = child
}
```

#### Concurrency

The pseudo-code in this spec is intentionally not written in a thread-safe manner to make it more concise.
Also, thread safety is highly platform/runtime dependent, and some don't support parallelism or concurrency.

However, if there can be a situation where multiple spans may end concurrently, agents MUST guard against race conditions.
To do that, agents should prefer [lock-free algorithms](https://en.wikipedia.org/wiki/Non-blocking_algorithm)
paired with retry loops over blocking algorithms that use mutexes or locks.

In particular, operations that work with the buffer require special attention.
- Setting a span into the buffer must be handled atomically.
- Retrieving a span from the buffer must be handled atomically.
  Retrieving includes atomically getting and clearing the buffer.
  This makes sure that only one thread can compare span properties and call mutating methods, such as `compress` at a time.
