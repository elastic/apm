## Agent Health Metrics

Agents SHOULD expose metrics which allow the analysis of the internal state of the agent, especially including the [reporting/transport mechanism](transport.md).

Many of these metrics are `COUNTER`s: a `COUNTER` is a monotonically increasing metric.
It is periodically reported by sending the difference of the counter-value now vs its value at the time of the previous report.
In order to save elasticsearch disk space, zero-increases are not sent.

Example:
| **Time** | **Counter** | **Reported Metric Value** |
|----------|-------------|---------------------------|
| 0s       | 7           | 7                         |
| 30s      | 10          | 3                         |
| 1m       | 10          | 0 (not sent)              |
| 1m30s    | 12          | 2                         |


### Event Count Metrics

Agents send their data to the Intake API of the APM-server in the form of a stream of events (e.g. transactions, spans, metricsets...).

The following metrics counting these events SHOULD be exposed:
 - `agent.events.total`: `COUNTER` of events either submitted to the internal reporting queue or dropped upon submit attempt
 - `agent.events.dropped.queue`: `COUNTER` of events where the attempt to add it to the reporting queue failed (e.g. due to a full queue)
 - `agent.events.dropped.error`: `COUNTER` of events dropped after they previously have been successfully added to the queue.

If an agent supports these metrics, the metrics MUST be captured for all events which would reach the APM-Server in an ideal, failure-free world.
Therefore an event MUST be taken into account for these metrics if an attempt is made to submit it to the internal reporting queue, regardless of the success.
Events dropped before this attempt (e.g. due to [sampling](tracing-sampling.md) or [transaction_max_spans](handling-huge-traces/tracing-spans-limit.md)) are NOT counted.

The value of `agent.events.dropped.error` is an upper bound for the actual number of dropped events after entering the queue.
For example, when a request to the Intake API fails without a response, all events within this request MUST be considered as failed.
In reality, it is possible that e.g. half of the data was actually successfully received and forwarded by the APM server.
When the APM server responds with an HTTP error code, the number of dropped events SHOULD be computed by subtracting the `accepted` field from the response body from the total number of inflight events of this request.

The `agent.events.total` metric MUST have the label `event_type`. The possible values for `event_type` are the lowercase names of the events according to the [spec](https://github.com/elastic/apm-server/tree/main/docs/spec/v2) (e.g. `transaction`, `metricset`) or the value `undefined`.
The `agent.events.dropped.*` metrics MUST NOT have any labels.

Agents SHOULD attempt to assign the appropriate label value based on the counted event. If this would impose significant implementation overhead, the value `undefined` MUST be used instead.

All event count metrics MUST be able to be disabled by the `disable_metrics` configuration option.

### Event Queue Metrics

The following metrics SHOULD be recorded by agents regarding the state of the internal event reporting queue:

 - `agent.events.queue.min_size.pct`: The smallest queue usage in percent (range [0-1]) observed since this metric was reported the last time
 - `agent.events.queue.max_size.pct`: The biggest queue usage in percent (range [0-1]) observed since this metric was reported the last time

We capture both `min_size` and `max_size` to allow to distinguish between reasons for why the queue is becoming full:
 * There is too much data captured / network errors: Both `min_size` and `max_size` are at `100%`
 * The data is collected in bursts for which the queue is not correctly sized: `max_size` is at `100%`, but `min_size` is low.

The queue usage can be computed based on how the agent defines the queue capacity.
E.g. if the queue capacity is a fixed number of events, the usage can be computed based on the current number of events.
If the queue capacity is in bytes, the usage can be computed based on the number of bytes currently occupied in the queue.

If agents use multiple queues (e.g. separating `metricsets` from other events), they SHOULD expose the `agent.events.queue.*` metrics for every queue and add a `queue_name` label.
The values for the `queue_name` label are implementation-defined.

All event queue metrics MUST be able to be disabled by the `disable_metrics` configuration option.

#### Possible implementation for agents

In order to track these metrics, most likely a custom implementation is required on top of the underlying queue.

One approach can be to have two variables `min_size` and `max_size`, which are atomically updated on changes to the queue:
 * When an item is added to the queue, update `max_size` with the current queue size if it is greater than `max_size`
 * When an item is removed from the queue, update `min_size` with the current queue size if it is less than `min_size`
 * When an item cannot be added to the queue (dropped), set `max_size` to `1`

After the metrics are exported, `min_size` and `max_size` need to be reset to the current queue size.

An atomic min/max can be implemented using the following algorithm:
```java
AtomicLong maxSize = new AtomicLong();

public void updateMaxSize(long currentSize) {
    //alternatively abort after like 10 iterations for constant latency
    while (true) { 
        long current = maxSize.get();
        if (current >= currentSize) {
            return;
        }
        boolean casSuccess = maxSize.compareAndSet(current, currentSize);
        if (casSuccess) {
            return;
        }
    }
}

```

### Event Request Metrics

Agents SHOULD expose the following metrics regarding Intake API networking:

 - `agent.events.requests.count`: `COUNTER` of the number of requests made or attempted to the Intake API of the APM server
 - `agent.events.requests.bytes`: `COUNTER` of the approximate number of bytes on the wire sent to the Intake API of the APM

The `agent.events.requests.*` metrics MUST have the label `success`, which can have the values `true` or `false`. A request is counted with `success=true` iff the APM Server responded with `2xx`.

The metric `agent.events.requests.bytes` does not need to represent the exact network usage.
Instead, the number of compressed bytes within the request body can be used as approximation.

All event request metrics MUST be able to be disabled by the `disable_metrics` configuration option.

### Agent Overhead Metrics

If possible with a reasonable amount of runtime and implementation overhead, agents MAY expose the following metrics for approximating their own resource usage:

 - `agent.background.cpu.overhead.pct`: The fraction of the process cpu usage caused by the agent in a range [0-1] within the last reporting interval.
 - `agent.background.cpu.total.pct`: The approximate CPU usage caused by the agent. Derived by multiplying `agent.background.cpu.overhead.pct` with `system.process.cpu.total.norm.pct`.
 - `agent.background.memory.allocation.bytes`: `COUNTER` of the number of bytes allocated in the main memory by the agent.
 - `agent.background.threads.count`: Number of currently running agent background threads at the time of reporting.

The `agent.background.threads.count` only applies to agents in whose language the concept of `threads` is present and used by the agent for background tasks.

Agents SHOULD add the label `task` to all these metrics. The values for `task` can be freely chosen by each agent implementation. The label values should be chosen in a way which allows the resource usages to be assigned to specific parts of the agent implementation (e.g. thread names as `task`s).

In most cases, it will not be feasible to capture the overhead of every action the agent does due to the overhead of the measurement itself. E.g. for the Java agent it is not feasible to measure the overhead of the code added to user application methods via instrumentation. Instead, only the overhead of agent-owned threads is measured.

The `agent.background.cpu.overhead.pct` can be computed by measuring the increase of thread CPU time of a given task ([this method](https://docs.oracle.com/javase/7/docs/api/java/lang/management/ThreadMXBean.html#getCurrentThreadCpuTime()) for Java) and dividing it by the increase of the total process CPU time ([this method](https://docs.oracle.com/javase/7/docs/jre/api/management/extension/com/sun/management/OperatingSystemMXBean.html#getProcessCpuTime()) for Java) within the same period.

All agent overhead metrics are enabled/disabled via the `agent_background_overhead_metrics` configuration:

|                |   |
|----------------|---|
| Type           | `boolean` |
| Default        | `false` |
| Dynamic        | `false` |
| Central config | `false` |
