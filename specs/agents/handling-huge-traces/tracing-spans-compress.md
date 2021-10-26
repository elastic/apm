# Compressing spans

To mitigate the potential flood of spans to a backend,
agents SHOULD implement the strategies laid out in this section to avoid sending almost identical and very similar spans.

While compressing multiple similar spans into a single composite span can't fully eliminate the collection overhead,
it can significantly reduce the impact on the following areas,
with very little loss of information:
- Agent reporter queue utilization
- Capturing stack traces, serialization, compression, and sending events to APM Server
- Potential to re-use span objects, significantly reducing allocations
- Downstream effects like reducing impact on APM Server, ES storage, and UI performance

### Configuration option `span_compression_enabled`

Setting this option to true will enable span compression feature.
Span compression reduces the collection, processing, and storage overhead, and removes clutter from the UI.
The tradeoff is that some information such as DB statements of all the compressed spans will not be collected.

|                |          |
|----------------|----------|
| Type           | `boolean`|
| Default        | `false`  |
| Dynamic        | `true`   |


## Consecutive-Exact-Match compression strategy

One of the biggest sources of excessive data collection are n+1 type queries and repetitive requests to a cache server.
This strategy detects consecutive spans that hold the same information (except for the duration)
and creates a single [composite span](#composite-span).

```
[                              ]
GET /users
 [] [] [] [] [] [] [] [] [] []
 10x SELECT FROM users
```

Two spans are considered to be an exact match if they are of the [same kind](#consecutive-same-kind-compression-strategy) and if their span names are equal:
- `type`
- `subtype`
- `destination.service.resource`
- `name`

### Configuration option `span_compression_exact_match_max_duration`

Consecutive spans that are exact match and that are under this threshold will be compressed into a single composite span.
This option does not apply to [composite spans](#composite-span).
This reduces the collection, processing, and storage overhead, and removes clutter from the UI.
The tradeoff is that the DB statements of all the compressed spans will not be collected.

|                |          |
|----------------|----------|
| Type           | `duration`|
| Default        | `50ms`    |
| Dynamic        | `true`   |

## Consecutive-Same-Kind compression strategy

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

### Configuration option `span_compression_same_kind_max_duration`

Consecutive spans to the same destination that are under this threshold will be compressed into a single composite span.
This option does not apply to [composite spans](#composite-span).
This reduces the collection, processing, and storage overhead, and removes clutter from the UI.
The tradeoff is that the DB statements of all the compressed spans will not be collected. 

|                |          |
|----------------|----------|
| Type           | `duration`|
| Default        | `5ms`    |
| Dynamic        | `true`   |

## Composite span

Compressed spans don't have a physical span document.
Instead, multiple compressed spans are represented by a composite span.

### Data model

The `timestamp` and `duration` have slightly similar semantics,
and they define properties under the `composite` context.

- `timestamp`: The start timestamp of the first span.
- `duration`: gross duration (i.e., _<last compressed span's end timestamp>_ - _<first compressed span's start timestamp>_).
- `composite`
    - `count`: The number of compressed spans this composite span represents.
      The minimum count is 2 as a composite span represents at least two spans.
    - `sum`: sum of durations of all compressed spans this composite span represents in milliseconds.
      Thus `sum` is the net duration of all the compressed spans while `duration` is the gross duration (including "whitespace" between the spans).
    - `compression_strategy`: A string value indicating which compression strategy was used. The valid values are:
        - `exact_match` - [Consecutive-Exact-Match compression strategy](tracing-spans-compress.md#consecutive-exact-match-compression-strategy)
        - `same_kind` - [Consecutive-Same-Kind compression strategy](tracing-spans-compress.md#consecutive-same-kind-compression-strategy)

### Effects on metric processing

As laid out in the [span destination spec](../tracing-spans-destination.md#contextdestinationserviceresource),
APM Server tracks span destination metrics.
To avoid compressed spans to skew latency metrics and cause throughput metrics to be under-counted,
APM Server will take `composite.count` into account when tracking span destination metrics.

### Effects on `span_count.started`

When a span is compressed into a composite, the `span_count.started` (or 
`span_count.reported`) should ONLY count the compressed composite as a single
span, spans that have been compressed into the composite should not be counted.

## Compression algorithm

### Eligibility for compression

A span is eligible for compression if all the following conditions are met
1. It's an [exit span](../tracing-spans.md#exit-spans)
2. The trace context of this span has not been propagated to a downstream service
3. If the span has `outcome` (i.e., `outcome` is present and it's not `null`) then it should be `success`.
  It means spans with outcome indicating an issue of potential interest should not be compressed.    

The second condition is important so that we don't remove (compress) a span that may be the parent of a downstream service.
This would orphan the sub-graph started by the downstream service and cause it to not appear in the waterfall view.

```java
boolean isCompressionEligible() {
    return exit && !context.hasPropagated && (outcome == null || outcome == "success") 
}
```

### Span buffering

Non-compression-eligible spans may be reported immediately after they have ended.
When a compression-eligible span ends, it does not immediately get reported.
Instead, the span is buffered within its parent.
A span/transaction can buffer at most one child span.

Span buffering allows to "look back" one span when determining whether a given span should be compressed.

A buffered span gets reported when
1. its parent ends
2. a non-compressible sibling ends

```java
void onEnd() {
    if (buffered != null) {
        report(buffered)
    }
}

void onChildEnd(Span child) {
    if (!child.isCompressionEligible()) {
        if (buffered != null) {
            report(buffered)
            buffered = null
        }
        report(child)
        return
    }

    if (buffered == null) {
        buffered = child
        return
    }
    
    if (!buffered.tryToCompress(child)) {
        report(buffered)
        buffered = child
    }
}
```

### Turning compressed spans into a composite span

Spans have `tryToCompress` method that is called on a span buffered by its parent.
On the first call the span checks if it can be compressed with the given sibling and it selects the best compression strategy.
Note that the compression strategy selected only once based on the first two spans of the sequence.
The compression strategy cannot be changed by the rest the spans in the sequence.
So when the current sibling span cannot be added to the ongoing sequence under the selected compression strategy
then the ongoing is terminated, it is sent out as a composite span and the current sibling span is buffered. 

If the spans are of the same kind, and have the same name and both spans `duration` <= `span_compression_exact_match_max_duration`,
we apply the [Consecutive-Exact-Match compression strategy](tracing-spans-compress.md#consecutive-exact-match-compression-strategy).
Note that if the spans are _exact match_
but duration threshold requirement is not satisfied we just stop compression sequence.
In particular it means that the implementation should not proceed to try _same kind_ strategy.
Otherwise user would have to lower both `span_compression_exact_match_max_duration` and `span_compression_same_kind_max_duration`
to prevent longer _exact match_ spans from being compressed. 

If the spans are of the same kind but have different span names and both spans `duration` <= `span_compression_same_kind_max_duration`,
we compress them using the [Consecutive-Same-Kind compression strategy](tracing-spans-compress.md#consecutive-same-kind-compression-strategy).

```java
bool tryToCompress(Span sibling) {
    isAlreadyComposite = composite != null
    canBeCompressed = isAlreadyComposite ? tryToCompressComposite(sibling) : tryToCompressRegular(sibling)  
    if (!canBeCompressed) {
        return false
    }
    
    if (!isAlreadyComposite) {
        composite.count = 1
        composite.sum = duration
    }
    
    ++composite.count
    composite.sum += other.duration
    return true 
}

bool tryToCompressRegular(Span sibling) {
    if (!isSameKind(sibling)) {
        return false
    }

    if (name == sibling.name) {
        if (duration <= span_compression_exact_match_max_duration && sibling.duration <= span_compression_exact_match_max_duration) {
            composite.compressionStrategy = "exact_match"
            return true
        }
        return false
    }

    if (duration <= span_compression_same_kind_max_duration && sibling.duration <= span_compression_same_kind_max_duration) {
        composite.compressionStrategy = "same_kind"
        name = "Calls to " + destination.service.resource
        return true
    }
    
    return false
}

bool tryToCompressComposite(Span sibling) {
    switch (composite.compressionStrategy) {
        case "exact_match":
            return isSameKind(sibling) && name == sibling.name && sibling.duration <= span_compression_exact_match_max_duration
                     
        case "same_kind":
            return isSameKind(sibling) && sibling.duration <= span_compression_same_kind_max_duration
    }
}
```

### Concurrency

The pseudo-code in this spec is intentionally not written in a thread-safe manner to make it more concise.
Also, thread safety is highly platform/runtime dependent, and some don't support parallelism or concurrency.

However, if there can be a situation where multiple spans may end concurrently, agents MUST guard against race conditions.
To do that, agents should prefer [lock-free algorithms](https://en.wikipedia.org/wiki/Non-blocking_algorithm)
paired with retry loops over blocking algorithms that use mutexes or locks.

In particular, operations that work with the buffer require special attention:
- Setting a span into the buffer must be handled atomically.
- Retrieving a span from the buffer must be handled atomically.
  Retrieving includes atomically getting and clearing the buffer.
  This makes sure that only one thread can compare span properties and call mutating methods, such as `compress` at a time.
