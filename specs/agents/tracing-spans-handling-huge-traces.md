# Handling huge traces

Instrumenting applications that make lots of requests (such as 10k+) to backends like caches or databases can lead to several issues:
- A significant performance impact in the target application.
  For example due to high allocation rate, network traffic, garbage collection, additional CPU cycles for serializing, compressing and sending spans, etc.
- Dropping of events in agents or APM Server due to exhausted queues.
- High load on the APM Server.
- High storage costs.
- Decreased performance of the Elastic APM UI due to slow searches and rendering of huge traces.
- Loss of clarity and overview (--> decreased user experience) in the UI when analyzing the traces.

Agents can implement several strategies to mitigate these issues:
- [Hard limit on number of spans to collect](tracing-spans-limit.md)
- [Collecting statistics about dropped spans](tracing-spans-dropped-stats.md)
- [Dropping fast spans](tracing-spans-drop-fast.md)
- [Compressing spans](tracing-spans-compress.md)

