#### Transaction sampling

To reduce processing and storage overhead, transactions may be sampled by agents.
Sampling here refers to "head-based sampling".

Head-based sampling is where a sampling decision is made at the root of the distributed trace,
before the details or outcome of the trace are known,
and propagated throughout the trace.

##### `transaction_sample_rate` configuration

By default, all transactions will be sampled.
Agents can be configured to sample probabilistically,
by specifying a sampling probability in the range \[0,1\].
e.g.

 - `1` means all transactions will be sampled (the default)
 - `0` means no transactions will be sampled
 - `0.5` means approximately 50% of transactions will be sampled

The maximum precision of the sampling rate is `0.001` (0.1%).
The sampling rate should be rounded half away from zero to 3 decimal places.
Values greater than `0` but less than `0.001` should be rounded to 0.001.

e.g.

    0.0001 -> 0.001
    0.5554 -> 0.555
    0.5555 -> 0.556
    0.5556 -> 0.556

The implementation will look something like `math.Round(sampleRate*1000)/1000`.
It is recommended to do that calculation once rather than every time the sampling rate is queried.
This is to ensure we are consistent when [propagating](#propagation) the sampling rate through `tracestate`.

|                |         |
|----------------|---------|
| Valid options  | \[0,1\] |
| Type           | `float` |
| Default        | `1`     |
| Dynamic        | `true`  |
| Central config | `true`  |

##### Effect on metrics

At the time of making a sampling decision,
the sampling rate must be recorded so that it can be associated with every transaction and span in the trace.
The sampling rate will be used by the server for scaling transaction and span metrics.

Transaction metrics will be used by the UI to display transaction distributions and throughput,
from the perspective of the transaction's service (grouped by `service.name` and `transaction.name`).

Span metrics will be used by the UI for inter-service request rates on service maps,
from the perspective of the requesting service (grouped by `service.name` and `destination.service.resource`).
These are also referred as edge metrics.

The server will calculate metrics by measuring only events from sampled traces,
and scaling the metrics based on the sampling rate associated with each one.
For example if the sampling rate is 0.5,
then each sampled transaction and span would be counted twice in metrics aggregations.

Metrics will be more accurate when the sampling rate is high.
With lower sampling rates the server is able to calculate representative, but less accurate, metrics.
If the sampling rate is 0 then no metrics will be calculated at all.

Agents will record the sampling rate on transactions and spans as `sample_rate`. e.g.

    {"transaction":{"name":"GET /","sample_rate":0.1,...}}
    {"span":{"name":"SELECT FROM table","sample_rate":0.1,...}}

For non-sampled transactions the `sample_rate` field _must_ be set to 0,
to ensure non-sampled transactions are not counted in transaction metrics.
This is important to avoid double-counting,
as non-sampled transactions will be represented in metrics calculated from sampled transactions.

When calculating transaction metrics,
if the `sample_rate` transaction field is missing,
the server will count each transaction (sampled and unsampled) as single events.
This is required for backwards compatibility with agents that do not send a sampling rate.

The server will only calculate span metrics for newer agents that include `sample_rate` in spans,
as otherwise the representative counts will be incorrect for sampling rates less than 1.

##### Non-sampled transactions

Currently _all_ transactions are captured by Elastic APM agents.
Sampling controls how much data is captured for transactions:
sampled transactions have complete context recorded and include spans;
non-sampled transactions have limited context and no spans.

For non-sampled transactions set the transaction attributes `sampled: false` and `sample_rate: 0`, and omit `context`.
No spans should be captured.

In the future we may introduce options to agents to stop sending non-sampled transactions altogether.

##### Propagation

As mentioned above, the sampling decision must be propagated throughout the trace.
We adhere to the W3C Trace-Context spec for this, propagating the decision through trace-flags: https://www.w3.org/TR/trace-context/#sampled-flag

In addition to propagating the sampling decision (boolean), agents must also propagate the sampling rate to ensure it is consistently attached to to all events in the trace.
This is achieved by adding an `s` attribute to our [`es` `tracestate` key](distributed-tracing.md#tracestate) with the value of the sampling rate.
e.g.

    tracestate: es=s:0.1,othervendor=<opaque>

As `tracestate` has modest size limits we must keep the size down.
This is ensured as the `transaction_sample_rate` configuration option has a maximum precision of 3 decimal places.

For non-root transactions the agent must parse incoming `tracestate` headers to identify the `es` entry and extract the `s` attribute.
The `s` attribute value should be used to populate the `sample_rate` field of transactions and spans.
If there is no `tracestate` or no valid `es` entry with an `s` attribute,
then the agent must omit `sample_rate` from non-root transactions and their spans.
