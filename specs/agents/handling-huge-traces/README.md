# Handling huge traces

Instrumenting applications that make lots of requests (such as 10k+) to backends like caches or databases can lead to several issues:
- A significant performance impact in the target application.
  For example due to high allocation rate, network traffic, garbage collection, additional CPU cycles for serializing, compressing and sending spans, etc.
- Dropping of events in agents or APM Server due to exhausted queues.
- High load on the APM Server.
- High storage costs.
- Decreased performance of the Elastic APM UI due to slow searches and rendering of huge traces.
- Loss of clarity and overview (--> decreased user experience) in the UI when analyzing the traces.

Agents can implement several strategies to mitigate these issues.
These strategies are designed to capture significant information about relevant spans while at the same time limiting the trace to a manageable size.
Applying any of these strategies inevitably leads to a loss of information.
However, they aim to provide a better tradeoff between cost and insight by not capturing or summarizing less relevant data.

- [Hard limit on number of spans to collect](tracing-spans-limit.md) \
  Even after applying the most advanced strategies, there must always be a hard limit on the number of spans we collect.
  This is the last line of defense that comes with the highest amount of data loss.
- [Collecting statistics about dropped spans](tracing-spans-dropped-stats.md) \
  Makes sure even if dropping spans, we at least have stats about them.
- [Dropping fast exit spans](tracing-spans-drop-fast-exit.md) \
  If a span was blazingly fast, it's probably not worth the cost to send and store it.
- [Compressing spans](tracing-spans-compress.md) \
  If there are a bunch of very similar spans, we can represent them in a single document - a composite span.

In a nutshell, this is how the different settings work in combination:

```java
if (span.transaction.spanCount > transaction_max_spans) {
    // drop span
    // collect statistics for dropped spans
} else if (compression possible) {
    // apply compression
} else if (span.duration < exit_span_min_duration) {
    // drop span
    // collect statistics for dropped spans
} else {
    // report span
}
```
