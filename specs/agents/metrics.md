## Metrics

Agents periodically collect and report various metrics, described below.

### System/process CPU/Heap

All agents (excluding JavaScript RUM) should record the following basic system/process metrics:

 - `system.cpu.total.norm.pct`: system CPU usage since the last report, in the range `[0,1]` (0-100%)
 - `system.process.cpu.total.norm.pct`: process CPU usage since the last report, in the range `[0,1]` (0-100%)
 - `system.memory.total`: total usable (but not necessarily available) memory on the system, in bytes
 - `system.memory.actual.free`: total available memory on the system, in bytes
 - `system.process.memory.size`: process virtual memory size, in bytes
 - `system.process.memory.rss.bytes`: process resident set size, in bytes
 
### cgroup metrics

Where applicable, all agents (excluding JavaScript RUM) should record the following cgroup metrics:

 - `system.process.cgroup.memory.mem.limit.bytes`
 - `system.process.cgroup.memory.mem.usage.bytes`

#### Metrics source

##### [cgroup-v1](https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt)
   - `system.process.cgroup.memory.mem.limit.bytes` - based on the `memory.limit_in_bytes` file
   - `system.process.cgroup.memory.mem.usage.bytes` - based on the `memory.usage_in_bytes` file

##### [cgroup-v2](https://www.kernel.org/doc/Documentation/cgroup-v2.txt)
   - `system.process.cgroup.memory.mem.limit.bytes` - based on the `memory.max` file
   - `system.process.cgroup.memory.mem.usage.bytes` - based on the `memory.current` file

#### Discovery of the memory files

All files mentioned above are located at the same directory. Ideally, we can discover this dir by parsing the `/proc/self/mountinfo` file, looking for the memory mount line and extracting the path from within it. An example of such line is: 
```
436 431 0:33 /docker/5042cfbb4ab36fcef9ca5f1eda54f40265c6ef3fe0694dfe34b9b474e70f8df5 /sys/fs/cgroup/memory ro,nosuid,nodev,noexec,relatime master:22 - cgroup memory rw,memory
```
The regex `^\d+? \d+? .+? .+? (.*?) .*cgroup.*memory.*` works in the cgroup-v1 systems tested so far, where the first and only group should be the directory path. However, it will probably take a few iterations and tests on different container runtimes and OSs to get it right. 
There is no regex currently suggested for cgroup-v2. Look in other agent PRs to get ideas.

Whenever agents fail to discover the memory mount path, they should default to `/sys/fs/cgroup/memory`.

#### Special values for unlimited memory quota

Special values are used to indicate that the cgroup is not configured with a memory limit. In cgroup v1, this value is numeric - `0x7ffffffffffff000` and in cgroup v2 it is represented by the string `max`. 
Agents should not send the `system.process.cgroup.memory.mem.limit.bytes` metric whenever these special values are set.

### Runtime

Agent should record runtime-specific metrics, such as garbage collection pauses. Due to their runtime-specific nature, these will differ for each agent.

When capturing runtime metrics, keep in mind the end use-case: how will they be used? Is the format in which they are recorded appropriate for visualization in Kibana? Do not record metrics just because it is easy; record them because they are useful.

### Transaction and span breakdown

Agents should record "breakdown metrics", which is a summarization of how much time is spent per span type/subtype in each transaction group. This is described in detail in the [Breakdown Graphs](https://docs.google.com/document/d/1-_LuC9zhmva0VvLgtI0KcHuLzNztPHbcM0ZdlcPUl64#heading=h.ondan294nbpt) document, so we do not repeat it here.

### Agent Health Metrics

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


#### Event Count Metrics

Agents send their data to the Intake API of the APM-server in the form of a stream of events (e.g. transactions, spans, metricsets...).

The following metrics counting these events SHOULD be exposed:
 - `agent.events.total`: `COUNTER` of events either submitted to the internal reporting queue or dropped upon submit attempt
 - `agent.events.dropped.queue`: `COUNTER` of events where the attempt to add it to the reporting queue failed (e.g. due to a full queue)
 - `agent.events.dropped.error`: `COUNTER` of events dropped after they previously have been successfully added to the queue.

If an agent supports these metrics, the metrics MUST be captured for all events which would reach the APM-Server in an ideal, failure-free world.
Therefore an event MUST be taken into account for these metrics if an attempt is made to submit it to the internal reporting queue, regardless of the success.
Events dropped before this attempt (e.g. due to [sampling](tracing-sampling.md) or [transaction_max_spans](handling-huge-traces/tracing-spans-limit.md)) are NOT counted.

The value of `agent.events.dropped.error` is an upper bound for the actual number of dropped events after entering the queue.
For example, when an request to the Intake API fails, all events within this request MUST be considered as failed.
In reality, it is possible that e.g. half of the data was actually successfully received and forwarded by the APM server.

All these metrics MUST have the label `eventType`. The possible values for `eventType` are the lowercase names of the events according to the [spec](https://github.com/elastic/apm-server/tree/main/docs/spec/v2) (e.g. `transaction`, `metricset`) or the value `other`.

Agents SHOULD attempt to assign the appropriate label value based on the counted event. If this would impose significant implementation overhead, the value `other` MUST be used instead.

All event count metrics are enabled/disabled via the `agent_event_metrics` configuration:

|                |   |
|----------------|---|
| Type           | `boolean` |
| Default        | `true` |
| Dynamic        | `true` |
| Central config | `true` |

#### Event Queue Metrics

The following metrics SHOULD be recorded by agents regarding the state of the internal event reporting queue:

 - `agent.events.queue.capacity`: The number of events the reporting queue can hold at maximum
 - `agent.events.queue.min_size`: The smallest number of events the queue contained since this metric was reported the last time
 - `agent.events.queue.max_size`: The biggest number of events the queue contained since this metric was reported the last time

We capture both `min_size` and `max_size` to allow to distinguish between reasons for why the queue is becoming full:
 * There is too much data captured / network errors: Both `min_size` and `max_size` are at `capacity`
 * The data is collected in bursts for which the queue is not correctly sized: `max_size` is at `capacity`, but `min_size` is low.

All event queue metrics are enabled/disabled via the `agent_event_metrics` specified [above](#event-count-metrics).

#### Event Request Metrics

Agents SHOULD expose the following metrics regarding Intake API networking:

 - `agent.events.requests.count`: `COUNTER` of the number of requests made or attempted to the Intake API of the APM server
 - `agent.events.requests.bytes`: `COUNTER` of the approximate number of bytes on the wire sent to the Intake API of the APM

All these metrics MUST have the label `success`, which can have the values `true` or `false`. A request is counted with `success=true` iff the APM Server responded with `2xx`.

The metric `agent.events.requests.bytes` does not need to represent the exact network usage.
Instead the number of compressed bytes within the request body can be used as approximation.

All event request metrics are enabled/disabled via the `agent_event_metrics` specified [above](#event-count-metrics).

#### Agent Overhead Metrics

If possible with a reasonable amount of runtime and implementation overhead, agents SHOULD expose the following metrics for approximating their own resource usage:

 - `agent.cpu.overhead.pct`: The fraction of the process cpu usage caused by the agent in a range [0-1] within the last reporting interval.
 - `agent.cpu.total.pct`: The approximate CPU usage caused by the agent. Derived by multiplying `agent.cpu.overhead.pct` with `system.process.cpu.total.norm.pct`.
 - `agent.memory.allocation.bytes`: `COUNTER` of the number of bytes allocated in the main memory by the agent.

Agents SHOULD add the label `task` to these metrics. The values for `task` can be freely chosen by each agent implementation. The label values should be chosen in a way which allows the resource usages to be assigned to specific parts of the agent implementation (e.g. thread names as `task`s).

In most cases, it will not be feasible to capture the overhead of every action the agent does due to the overhead of the measurement itself. E.g. for the Java agent it is not feasible to measure the overhead of the code added to user application methods via instrumentation. Instead, only the overhead of agent-owned threads is measured.

The `agent.cpu.overhead.pct` can be computed by measuring the increase of thread CPU time of a given task ([this method](https://docs.oracle.com/javase/7/docs/api/java/lang/management/ThreadMXBean.html#getCurrentThreadCpuTime()) for Java) and dividing it by the increase of the total process CPU time ([this method](https://docs.oracle.com/javase/7/docs/jre/api/management/extension/com/sun/management/OperatingSystemMXBean.html#getProcessCpuTime()) for Java) within the same period.

All agent overhead metrics are enabled/disabled via the `agent_overhead_metrics` configuration:

|                |   |
|----------------|---|
| Type           | `boolean` |
| Default        | `false` |
| Dynamic        | `true` |
| Central config | `true` |

## Shutdown behavior

Agents should make an effort to flush any metrics before shutting down.
If this cannot be achieved with shutdown hooks provided by the language/runtime, the agent should provide a public API that the user can call to flush any remaining data.