This specification document describes the integration and communication between the universal profiling host agent and apm-agents.
The goal is to enrich both profiling and APM data with correlation information to allow linking and filtering based of concepts from both worlds.

# General Approach

The profiling host agent runs as a standalone process with root rights. The apm-agents in contrast run within the user application process, which is likely to have limited permissions and to also be containerized.

Due to this mismatch in permissions all communication is actually initiated from the host-agent:
 * The APM agent exposes the information it wants to send to the profiler host agent in native memory at "well known" (defined below) locations. Using its root permissions, the host agent reads this memory.
 * The APM agent creates a `DGRAM` socket for receiving messages. The profiler host agent connects to it (again, using its root permissions) and sends messages to the APM agent.

# APM Agent exposed memory

The APM agent "sends" information to the profiling host agent by exposing this information in native memory.
The pointers to this native memory MUST be stored in native global variables (exported symbols) with the following names:
```
thread_local void* elastic_apm_profiling_correlation_tls_v1 = nullptr;

void* elastic_apm_profiling_correlation_process_storage_v1 = nullptr;
```

The profiling host agent is capable of detected these global variables in processes and can read the memory they point to.
Note that we use two variables because we expose two types of storage:
 * thread-local information (e.g. trace-id, span-id)
 * process-level information (e.g. service-name)

The variables are suffixed with `_v1`. If we require breaking changes in the future, this allows us to introduce a `_v2`.
For backwards compatibility with older host agent versions agents can then expose both `_v1` and `_v2` variables at the same time.

The `thread_local` variables must be compiled with the `TLSDESC` model in order to be readable by the profiler host agent. This means that corresponding GCC arguments must be used when compiling the native library:
 * ARM64: `-ftls-model=global-dynamic -mtls-dialect=desc`
 * x86_64: `-ftls-model=global-dynamic -mtls-dialect=gnu2`

## General Memory Layout

The shared memory always uses the native endianess of the current platform for multi-byte numbers.
Strings are always UTF-8 length encoded:
```
┌─────────────────┬──────────────────────────┐
│ length : uint32 │ utf8-str : uint8[length] │
└─────────────────┴──────────────────────────┘
```
`utf8-str` is not null-terminated, the length is already defined by the `length` field.
In the remainder of the document the type `utf8-str` is used to denote the encoding shown above.

## Process Storage Layout

This section explains the layout of the memory to which the `elastic_apm_profiling_correlation_process_storage_v1` variable points.
Note that `elastic_apm_profiling_correlation_process_storage_v1` MUST only point to a non-zero memory location when that memory has been fully initialized with the layout described in this section!

Name                  | Data type 
--------------------- | -------------
layout-minor-version  | uint16
service-name          | utf8-str
service-environment   | utf8-str
socket-file-path      | utf8-str

* *layout-minor-version*: Always `1` for now. The minor version will be incremented when new fields are added to the storage (non breaking changes).
* *service-name*: The APM service name of the process
* *service-environment*: The configured environment name for this process (e.g. production, testing, dev)
* *socket-file-path*: The APM Agent opens a UNIX domain socket for receiving messages from running profiler host agents (See [this section](#messaging-socket). This field contains the path to the socket file as seen from the process running the APM Agent (e.g. within the container).

## Thread Local Storage Layout

This section explains the memory layout of the memory to which the `elastic_apm_profiling_correlation_tls_v1` thread local variable points.
Note that `elastic_apm_profiling_correlation_tls_v1` MUST only point to a non-zero memory location when that memory has been fully initialized for that thread with the layout described in this section! Multiple threads must not share their memory area.

Name                  | Data type 
--------------------- | -------------
layout-minor-version  | uint16
valid                 | uint8
trace-present         | uint8
trace-flags           | uint8
trace-id              | uint8[16]
span-id               | uint8[8]
transaction-id        | uint8[8]

* *layout-minor-version*: Always `1` for now. The minor version will be incremented when new fields are added to the storage (non breaking changes).
* *valid*: Set to `0` by the APM-agent if it currently is in the process of updating this thread local storage and to non-zero after the update is done. The profiling host agent MUST ignore any data read if this value is `0`.
* *trace-present*: `1` if there currently is a trace active on this thread, `0` otherwise. If the value is `0`, the profiler host agent must ignore the `trace-flags`, `trace-id`, `span-id` and `transaction-id` fields
* *trace-flags*: Corresponds to the [W3C trace flags](https://www.w3.org/TR/trace-context/#trace-flags) of the currently active trace
* *trace-id*: The W3C trace id of the currently active trace
* *span-id*: The W3C trace id of the currently active span
* *transaction-id*: The W3C span id of the currently active transaction (=the local root span)

APM-agents MAY start populating the thread-local storage only after receiving a host agent [registration message](#profiler-registration-message)

### Concurrency-safe Updates

The profiler might interrupt a thread and take a profiling sample while that thread is in the process of updating the contents of the shared thread local storage. Fortunately, we have the following guarantees about this interruption:
 * While the profiler is taking a sample, the thread being sampled is guaranteed to be "paused" (no parallelism involved, only concurrency)
 * The profiler will read the thread local storage on the same CPU core as the thread writing it, therefore we won't have any problems with memory / cache visibility

Based on these guarantees we can safely perform updates to the thread local storage the following way:
 * Before updating anything else, the APM-agent sets the `valid`-byte to `0`
 * The APM agent updates the thread local storage content (e.g. `span-id`)
 * Finally, the APM-agent sets the `valid`-byte to `1`

This way, the profiler is able to detect and discard incomplete data by inspecting the `valid` byte.

Note that APM-agents must make sure that compilers do not reorder the steps listed above.
For Java for example this can be achieved by inserting volatile writes after setting the `valid` byte to `0` and before setting it back to `1`.

# Messaging Socket

In order to receive profiling data from the profiling host agent, APM agents MUST create a Datagram Unix Domain Socket. We use that kind of socket because:
 * The socket is reliable and ensures "packet boundaries". This means we don't have to deal with buffering and reassembling partial messages
 * If multiple senders send to the same socket (e.g. multiple profiler host agents are active), their packets stay separated

Here is a code example on how to open a corresponding non-blocking socket at a given filepath:
```c
void createProfilerSocket(const char* filepath) {
    int fd = socket(PF_UNIX, SOCK_DGRAM, 0);
    if (fd == -1) {
        //handle error
    }
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags == -1) {
                close(fd);
        //handle error
    }
    if(fcntl(fd, F_SETFL, flags | O_NONBLOCK) != 0){
        close(fd);
        //handle error
    }

    sockaddr_un addr = { .sun_family = AF_UNIX };
    strncpy(addr.sun_path, filepath, sizeof(addr.sun_path) - 1);

    if (bind(fd, (sockaddr*)&addr, sizeof(addr) ) < 0) {
        close(fd);
        //handle error
    }
}
```

And here how to read a messages in a non-blocking way:

```c
size_t readProfilerSocketMessages(uint8_t* outputBuffer, size_t bufferSize) {
    int n = recv(profilerSocket, outputBuffer, bufferSize, 0);
    if (n == -1) {
        if(errno == EAGAIN || errno == EWOULDBLOCK) {
            return -1; //no message to read
        } else {
            //something went wrong, handle error
        }
    }
    if(n == bufferSize) {
        //handle error, message might have been truncated
    }
    return n; //n is the size of the received message
}
```

Note that in certain edge cases (e.g. a full buffer on the sender side) messages might have been truncated! APM-agents must protected against this by detecting messages that are shorter than expected from the message type and version, discarding the message.

The agent may create the file for the socket binding at any path and with any filename it likes.
The path to the opened socket must be exposed in the process storage field `socket-file-path`.
The process storage MUST NOT be initialized and exposed before the socket has been created.

## Message Format

All messages have the following layout:
```
┌───────────────────────┬────────────────────────┬─────────────┐
│ message-type : uint16 │ minor-version : uint16 │ payload : * │
└───────────────────────┴────────────────────────┴─────────────┘
```

* *message-type* : An ID uniquely identifying the type (and therefore payload structure) of the message.
* *minor-version* : The version number for the given *message-type*. This value is incremented when new fields are added to the payload while preserving the *message-type* (non breaking changes). For breaking changes a new *message-type* must be used.

## Profiler Registration Message

Whenever the profiling host agent starts communicating for the first time with a process running an APM Agent, it MUST send this message.
This message is used to let the APM-agent know that a profiler is actually active on the current host. Note that an APM-agent may receive this message zero, one or several times: this may happen if no host agent is active, if one is active or if a host agent is restarted during the lifetime of the APM-agent respectively.

The *message-type* is `2` and the current *minor-version* is `1`.

The payload layout is as follows:
Name                  | Data type 
--------------------- | -------------
samples-delay-ms      | uint32
host-id               | utf8-str

* *samples-delay-ms*: A sane upper bound of the usual time taken in milliseconds by the profiling host agent between the collection of a stacktrace and it being written to the apm-agent via the [messaging socket](#cpu-profiler-trace-correlation-message). The APM-agent will assume that all profiling data related to a span has been written to the socket if a span ended at least the provided duration ago. Note that this value doesn't need to be a hard a guarantee, but it should be the 99% case so that profiling data isn't distorted in the expected case.
* *host-id*: The [`host.id` resource attribute](https://opentelemetry.io/docs/specs/semconv/attributes-registry/host/) used for the profiling data by this profiling host agent. If an APM-agent is already sending a `host.id` it MUST print a warning if the `host.id` is different and otherwise ignore the value received by the host agent. A mismatch will lead to certain correlation features (e.g. cost and CO2 consumption) not working. If an agent does not collect the `host.id` by itself, it MUST start sending the `host.id` after receiving it from the profiler host agent to ensure aforementioned correlation features work correctly.


## CPU Profiler Trace Correlation Message

Whenever the profiler is able to correlate a taken CPU stacktrace sample with an APM trace (see [this section](#thread-local-storage-layout)). It sends the ID of the stacktrace back to the APM agent.

The *message-type* is `1` and the current *minor-version* is `1`.

The payload layout is as follows:
Name                  | Data type 
--------------------- | -------------
trace-id              | uint8[16]
transaction-id        | uint8[8]
stack-trace-id        | uint8[16]
count                 | uint16

* *trace-id*: The APM W3C trace id of the trace which was active for the given profiling samples
* *transaction-id*: The APM W3C span id of the transaction which was active for the given profiling samples
* *stack-trace-id*: The unique ID for the stacktrace captured assigned by the profiler. This ID is stored in elasticsearch in base64 URL safe encoding by the universal profiling solution.
* The number of samples observed since the last report for the (*trace-id*, *transaction-id*, *stack-trace-id*) combination.