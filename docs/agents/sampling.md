# Sampling

To reduce processing and storage overhead, transactions may be sampled by agents.
Sampling here refers to "head-based sampling".
Head-based sampling is where a sampling decision is made at the root of the distributed trace, before the details or outcome of the trace are known, and propagated throughout the trace.

## Configuration

Agents can be configured to sample probabilistically, by specifying a sampling probability in the range \[0,1\] using the configuration `ELASTIC_APM_TRANSACTION_SAMPLE_RATE`. e.g.

 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=1` means all transactions will be sampled (the default)
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0` means no transactions will be sampled
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0.5` means approximately 50% of transactions will be sampled

## Sampling rate

At the time of making a sampling decision, the sampling rate must be recorded so that it can be associated with every transaction and span in the trace.
This will be used by the server for scaling transaction and span metrics.
These metrics are used in the service map to display performance and throughput both from the perspective of the service itself (transaction metrics grouped by `service.name`) and from the perspective of upstream services (exit span metrics grouped by `destination.service.resource`).

These metrics will be more accurate when the sampling rate is high.
But even with lower sampling rates,
the server is able to calculate representative metrics.
To enable the server to properly weigh the metrics, agents must record the sampling rate on transactions and spans as `sample_rate`. e.g.

    {"transaction":{"name":"GET /","sample_rate":0.1,...}}
    {"span":{"name":"SELECT FROM table","sample_rate":0.1,...}}

For non-sampled transactions the `sample_rate` field _must_ be set to 0.
For backwards compatibility the server will assume a value of 1 where the field is unspecified,
resulting in all transactions (sampled and unsampled) being counted equally in metrics.

## Non-sampled transactions

Currently _all_ transactions are captured by Elastic APM agents.
Sampling controls how much data is captured for transactions: sampled transactions have complete context recorded, and include spans;
non-sampled transactions have limited context and no spans.

For non-sampled transactions set the transaction attributes `sampled: false` and `sample_rate: 0`, and omit `context`.
No spans should be captured.

In the future we may introduce options to agents to stop sending non-sampled transactions altogether.

## Propagation

As mentioned above, the sampling decision must be propagated throughout the trace.
We adhere to the W3C Trace-Context spec for this, propagating the decision through trace-flags: https://www.w3.org/TR/trace-context/#sampled-flag

In addition to propagating the sampling decision (boolean), agents must also propagate the sampling rate to ensure it is consistently attached to to all events in the trace.
This is achieved by adding an `s` attribute to our [`es` `tracestate` key](distributed-tracing.md#tracestate) with the value of the sampling rate.
e.g.

    tracestate: es=s:0.1,othervendor=<opaque>

As `tracestate` has modest size limits we must keep the size down.
When recording `s` in `tracestate` the sampling rate should be rounded half away from zero to 3 decimal places.
e.g.

    0.5554 -> 0.555
    0.5555 -> 0.556
    0.5556 -> 0.556

The implementation will look something like `math.Round(sampleRate*1000)/1000`.

For non-root transactions the agent must parse incoming `tracestate` headers to identify the `es` entry and extract the `s` attribute.
The `s` attribute value should be used to populate the `sample_rate` field of transactions and spans.
If there is no `tracestate` or no valid `es` entry with an `s` attribute,
then the agent must omit `sample_rate` from non-root transactions and their spans.
