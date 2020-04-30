# APM Agents as log shippers

## The Problem
Although the [ecs-logging](https://github.com/elastic/ecs-logging) initiative helps to get started with centralized logging more easily, there's still lots of things a user has to configure to get started.
1. Re-configure the application logging
  1.1. Add a dependency to the ecs log formatter
  1.2. Change logging configuration
2. Enable APM/log correlation
3. Configure Filebeat

## The solution
The goal is to have no manual steps, aside from adding the agent and maybe enable log collection via a config.
Implementing this is optional for every APM agent.

### Part 1: ship agent logs 
Make the APM agents tail their own [ecs-json](https://github.com/elastic/ecs-logging)-formatted log file and send it to APM Server which sends it to Elasticsearch.

### Part 2: ship application logs
The agent re-configures the monitored application to “shadow” each of the application’s log file with a ecs-json-formatted variant.

That log can then either be shipped by Filebeat/Elastic Agent or the APM agent.

## Benefits
* Easier onboarding: "throw in" agent into the app and get logs, metrics and traces (incl. APM/log correlation)
* Makes it easy for ops: Centralized logging with zero configuration within the app - no dependency on dev team
* Centralized logging for agent logs - better supportability
* Drive awareness for APM in our logging user base
  The easiest way to get started with centralized logging is to let the APM agent automagically do it

## What about Elastic Agent?
* Elastic Agent is not replacing standalone Java agent
* Not having a dependency on Elastic Agent lets us do it now
* When Elastic Agent comes along, we can also integrate with it
* Filebeat can be used to ship the logs instead of the APM Agent for more advanced use cases or better delivery guarantees
* If we see that shipping the logs from the Agent doesn't have value anymore because Elastic Agent is the standard for installing the Java agent, we can deprecate it.

## Why log to a file vs send logs directly over the network?
* When APM Server is down for a while, the log file acts as a buffer
* The agent continues sending when the server gets back up again
* If the application crashes logs are sent when it restarts
* Lower memory footprint as logs don't have to be buffered in memory

## Implementation details

### Log tailing
* The agent starts a background thread that constantly looks for new data in the file(s)
* If there is new data, it writes it to the HTTP request body using a reusable byte buffer
* The log tailing is designed to work with multiple files
* Works with log rotation
  * If the file has been fully read, it checks if there's a new one

### Persistent state
* Creates a `${logfile}.state` file, storing the position and creation time of the log file
* Tries to aquire a file lock on the state file to ensure the file is only tailed once

#### Delivery guarantees ack/nak
* Only if the APM Server responds with a 200, the curret state is acknowledged an written to the `.state` file
* If the APM Server returns an error code or if there's any network error, the previous state is restored (negative acknowledge)
* If the APM Server can guaranee at-least-once delivery after returning a 200, the whole process has a at-least-once delivery guarantee

#### Handling of file rotation
* The file might be rotated as we are reading it `apm.log` -> `apm-1.log` or `apm.log1`
* As we keep the file handle open, renaming doesn't affect reading
* If the agent restarts, it checks via the creation time which file to continue reading from
  * If the file `${logfile}` has the same creation time we assume it has not been rotated
  * If the creation time is different, search for a file in the same directory with that creation time


### APM Server logs endpoint

The endpoint would look similar to the current event intake API.

Example:
```bash
curl -H 'Content-Type: application/x-ndjson' -XPOST localhost:8200/intake/v2/logs -d \
'{"metadata":{"service":{"name":"my-service","process":{"pid":32146,"ppid":3372},"system":{"architecture":"x86_64","hostname":"localhost","platform":"Mac OS X"}}}
{"metadata":{"log":{"file":{"path":"/var/log/apm.log","name":"apm.log"}}}}
{"@timestamp":"2020-04-08T06:34:44.045Z", "log.level": "INFO", "message":"Hello World", "process.thread.name":"main","log.logger":"co.elastic.apm.agent.Foo"}
{"@timestamp":"2020-04-08T06:34:44.045Z", "log.level": "INFO", "message":"Hello World 2", "process.thread.name":"main","log.logger":"co.elastic.apm.agent.Foo"}
{"metadata":{"log":{"file":{"path":"/var/log/app.log","name":"app.log"}}}}
{"@timestamp":"2020-04-08T06:34:44.045Z", "log.level": "INFO", "message":"Hello World", "process.thread.name":"main","log.logger":"org.example.MyApplication"}
'
```

#### Metadata
The biggest difference is that there are two kinds of `metadata` events.
The one that is sent in the first line is enhancing all log events within a request.
The second type of `metadata` enhances the fields for all events until another `metadata` event comes along.

The reason for this is that more than one file can be tailed and sent in one request. Each file has its own metadata like the file name and path that should not be repeated for each log line.

#### File content
In-between the `metadata` events, the exact content of the log file is sent. There's no need to parse the JSON in the file.
The layout of the log files are guaranteed to be nd-json.

#### Validation and error handling
Another difference compared to the event intake API is in regards to validation and error handling.
Even if a log line can't be parsed or contains conflicting mappings (such as `"foo": "bar", "foo": "baz", "foo.bar": "baz"`), the APM Server should not discard the events.
Instead, it should index the raw event and the error message into Elasticsearch, similar to how Filebeat would handle that.

#### Delivery guarantees
Can the APM Server guarantee a at-least-once delivery after sending a `200` response to the APM agent?
Could there be a switch to trade off performance (put in memory queue) vs stronger delivery guarantees (put in on-disk queue)?
