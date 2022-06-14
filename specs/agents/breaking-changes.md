# What is a breaking change in a version of an APM agent?
A change is defined as breaking if it causes an application using an APM agent to break or if the APM product is no longer usable in a way that it previously was.

Taken strictly, this definition could lead to treating every change in runtime behavior as a breaking change. At the same time, we need to be able to keep driving improvements to existing features of our APM product. This document gives some guidelines to help distinguish changes of implementation details from breaking changes.

## Types of breaking changes
### Instrumentation versions
Each agent instruments a number of libraries that are used in their language ecosystem. These libraries themselves may introduce new versions, breaking changes, and deprecate older versions. The APM agents therefore will occasionally introduce changes in their instrumentation of external libraries. The changes that we consider breaking are ones that remove support for older versions. Agents can also continue supporting the instrumentation of a particular older library version but drop its testing of it because of some conflicts in installing test suite dependencies, for example. This change would not be considered breaking as long as it’s properly documented.

### Language support
Similar to library version instrumentation, APM agents will typically support multiple versions of its language. Sometimes it is necessary to drop support for older versions of the languages as they themselves are EOL’ed. It is considered a breaking change when an APM agent drops support for a particular language version.

### Configuration changes
All agents support a set of configuration options and default values. Changes to the configuration offering can be categorized into two types:

__Change in default configuration value__: Each APM agent configuration option has a default value. Sometimes we change what that default configuration value is. We should consider the _effect_ of changing the value when we evaluate whether the change is breaking. For example, the default configuration value could enrich the data and provide an enhanced experience to the user. In this case, we wouldn’t consider the change to be breaking. On the other hand, if a default value is changed, and as a consequence, removes some information the user was previously able to see, we would consider that a breaking change.

__Removal of a configuration option__: It is a breaking change to remove a configuration option. For example, APM agents may have removed the option `active` in favor of a new option, `enabled`.

__Change in configuration value behavior__: If the semantics of a configuration value are altered, the change is considered breaking. For example, the configuration option `span_frames_min_duration` can be set to an integer millisecond value, 0, or -1. At the time this document was written, setting this value to 0 means to collect no stack traces and -1 means to collect all stack traces. If there is a change in what the special values 0 and -1 mean, the change is a breaking one.

### Public API changes
Each APM agent has a Public API that is marked as such and documented. Agents may make a change to their Public API in order to support new features, support new integrations, resolve inconsistencies between agents, or for other reasons.

__Public API__: When the name of a Public API component is changed or if a component is removed, this change is considered breaking. Applications may depend on the APM agent’s Public API so the agent would ideally issue a deprecation warning and clearly document the upcoming change for users before the version including the change is released. For example, changing the Public API for setting the `service.destination.resource` value to setting two new fields instead (`service.target.name`, `service.target.type`) is considered to be a breaking change.

__Public API behavior__: If the effects of using a part of the Public API or the semantics of that API are changed to enhance a user experience or enrich the data in some way, we don’t consider it a breaking change. A Public API behavior change that removes or alters some information that was there before is considered breaking.

### APM server support
__Support for APM server versions__: If an APM agent removes support for an older APM server version, the change is considered breaking.

__Support for APM server protocols__: Similarly, if the APM agent removes support for an APM server protocol, the change is breaking.


## What is not a Breaking change
In general, we don’t consider changes in the data we collect to be breaking. Some examples of these changes are:
- Span metadata, such as the span name or the structured `db.statement`, or destination granularity
- Span compression (multiple similar or exact consecutive spans collapsed into one)
- Trace structure (e.g. span links + handling of messaging)

