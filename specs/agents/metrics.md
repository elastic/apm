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
 - `system.process.cgroup.memory.stats.inactive_file.bytes`

#### Metrics source

##### [cgroup-v1](https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt)
   - `system.process.cgroup.memory.mem.limit.bytes` - based on the `memory.limit_in_bytes` file
   - `system.process.cgroup.memory.mem.usage.bytes` - based on the `memory.usage_in_bytes` file
   - `system.process.cgroup.memory.stats.inactive_file.bytes` - based on the `total_inactive_file` line in the `memory.stat` file

##### [cgroup-v2](https://www.kernel.org/doc/Documentation/cgroup-v2.txt)
   - `system.process.cgroup.memory.mem.limit.bytes` - based on the `memory.max` file
   - `system.process.cgroup.memory.mem.usage.bytes` - based on the `memory.current` file
   - `system.process.cgroup.memory.stats.inactive_file.bytes` - based on the `inactive_file` line in the `memory.stat` file

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

When capturing runtime metrics, keep in mind the end use-case: how will they be used? Is the format in which they are recorded appropriate for visualisation in Kibana? Do not record metrics just because it is easy; record them because they are useful.

### Transaction and span breakdown

Agents should record "breakdown metrics", which is a summarisation of how much time is spent per span type/subtype in each transaction group. This is described in detail in the [Breakdown Graphs](https://docs.google.com/document/d/1-_LuC9zhmva0VvLgtI0KcHuLzNztPHbcM0ZdlcPUl64#heading=h.ondan294nbpt) document, so we do not repeat it here.
