# Sampling

To reduce processing and storage overhead, transactions may be sampled
by agents. Sampling here refers to "head-based sampling", where a sampling
decision is made at the root of the distributed trace, before the details
or outcome of the trace are known, and propagated throughout the trace.

## Configuration

Agents can be configured to sample probabilistically, by specifying a
sampling probability in the range \[0,1\] using the configuration
`ELASTIC_APM_TRANSACTION_SAMPLE_RATE`. For example:

 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=1` means all transactions will be sampled (the default)
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0` means no transactions will be sampled
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0.5` means approximately 50% of transactions will be sampled

## Sampling weight

At the time of making a sampling decision, a "sampling weight" must be calculated.
This value represents the approximate number of traces that the sampled trace is
representative of. Every transaction and span in the trace must have the same weight.

For probabilistic sampling, the weight is the inverse of the sampling rate.
e.g. for a sampling rate of 0.5, the weight is 1/0.5=2; for a sampling rate of 0.2,
the weight is 1/0.2=5.

Sampling weight must be recorded on transactions and spans as "weight". e.g.

    {"transaction":{"name":"GET /","weight":5,...}}
    {"span":{"name":"SELECT FROM table","weight":5,...}}

For non-sampled transactions the weight must be recorded as 0. For backwards
compatibility the server will assume a value of 1 if unspecified.

## Non-sampled transactions

Currently, _all_ transactions are captured by Elastic APM agents. Sampling
controls how much data is captured for transactions: sampled transactions
have complete context recorded, and include spans; non-sampled transactions
have limited context, and no spans.

For non-sampled transactions, set the transaction attributes `sampled: false`
and `weight: 0`, and omit `context`. No spans should be captured. In the future
we may introduce options to agents to stop sending non-sampled transactions
altogether.

## Propagation

As mentioned above, the sampling decision must be propagated throughout the trace.
We adhere to the W3C Trace-Context spec for this, propagating the decision through
trace-flags: https://www.w3.org/TR/trace-context/#sampled-flag

In addition to propagating the sampling decision (boolean), agents must also propagate
the sampling weight to ensure a consistent weight is applied to all events in the trace.
This is achieved by adding a `w` attribute to our [`elastic` `tracestate` key](distributed-tracing.md#tracestate) when calculating the
sampling weight.

For example:

    tracestate: elastic=w:5,othervendor=<opaque>

The "w" attribute should be a number. As `tracestate` has modest size limits, we must
keep the size down. If "w" has more than 5 significant figures before the decimal point,
then round half away from zero to the nearest integer. Otherwise, round half away from
zero to 5 significant figures. e.g.

    1.23455 -> 1.2346
    12345.5 -> 12346

For a downstream agent, if `tracestate` is not found or does not contain an "elastic"
entry with a "w" attribute, then it must assume a sample weight of 1 just as the server
does for backwards compatibility.
