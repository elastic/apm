# Discarding fast spans

Currently,
the experience of our APM solution is not ideal when monitoring an application that ends up generating thousands of spans per request.

We currently have a default limit of 500 spans in the agents and 1000 spans in the UI to prevent overwhelming the system with too many spans.
However,
that just cuts off at a certain point without considering which spans are important and which are not.

## `span_min_duration` configuration

Sets the minimum duration of spans.
Spans that execute faster than this threshold are attempted to be discarded.

The attempt fails if they lead up to a span that can't be discarded.
Spans that propagate the trace context to downstream services,
such as outgoing HTTP requests,
can't be discarded.
Additionally, spans that lead to an error or that may be a parent of an async operation can't be discarded.

However, external calls that don't propagate context,
such as calls to a database, can be discarded using this threshold.

|                |                                 |
|----------------|---------------------------------|
| Type           | `integer`                       |
| Default        | `0ms` (don't discard any spans) |
| Dynamic        | `true`                          |
| Central config | `true`                          |

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

### Intermediate spans

Discarding a single span that has both a parent and a child span is not possible as it would lead to orphaned child spans.

However,
a whole subtree of spans can get discarded if all spans within that tree are requesting to be discarded.
This means that if a leaf of the tree can't be discarded because it propagates context downstream,
all spans leading up to it can't be discarded.
If the leaf is a non-context propagating span,
such as a manually created span or a SQL call,
the subtree can be discarded.

### Spans that lead up to async spans can't be discarded

Whenever the context of a span is captured when scheduling an async operation,
this span may not be discarded.

That is because when the async operation is executed, 
and the span context gets restored,
the async operation might create child spans of the first span,
even if it has already ended,
or concurrently to it ending.
In this scenario, discarding the first span would orphan the async span.

This is even true if it's unknown whether the async operation creates a span at all.

Propagating the trace context to async operations is also known as in-process context propagation.

## Implementation

Spans store two flags in order to determine whether a span can be discarded:
- `discardable`:
  Whether discarding this span is allowed.
  The default value is `true`.
  Setting this to `false` also sets the `discardable` flag of all it's parents and grand-parents to `true`.
  See also [Intermediate spans](#Intermediate-spans).
- `discardRequested`:
  Whether this span is requested to be discarded.
  The default value is `false`
  
### Marking as non-discardable

According to the [limitations](#Limitations),
there are certain situations where a span (and thus all it's parents) are marked as non-discardable.

 - When an error is reported for this span
 - When the span is reported to APM Server
 - On out-of-process context propagation 
 - On in-process context propagation

### Request discarding

If the span's duration is lower than `span_min_duration`,
the span is requested to be discarded.

### Determining whether to report a span

If the span is requested to be discarded and discardable,
the `span_count.dropped` count is incremeted and the span will not be reported.
We're deliberately using the same dropped counter we also use when dropping spans due to `transaction_max_spans`.

### Impact on breakdown metrics

Discarded spans contribute to breakdown metrics the same way as non-discarded spans.

### Impact on `transaction_max_spans`

Before creating a span,
agents must determine whether creating that span would exceed the limit (`transaction_max_spans`).
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
