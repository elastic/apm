### Distributed Tracing

We implement the W3C standards, both for HTTP headers and binary fields.

#### Http Headers

Our implementation relies on the [W3C Trace Context](https://www.w3.org/TR/trace-context-1/) standard. Until this standard became final,
we used the header name `elastic-apm-traceparent` and we did not support `tracestate`. Soon after the standard became official, we
started to fully align with it. For backward compatibility reasons, this was done in phases, so that the first step was to look for both
`traceparent` headers in incoming requests (meaning - both `elastic-apm-traceparent` and `traceparent`) and sending both `traceparent` headers in outgoing requests (with the exception of the RUM agent,
due to CORS). [Issue #71](https://github.com/elastic/apm/issues/71) describes this in more detail, as well as tracking implementation
in the different agents.
New agents may decide whether to support both `traceparent` headers (so to be compatible with older agent versions) or only the formal W3C
header.

#### Binary Fields

Our implementation relies on the [W3C Binary Trace Context](https://w3c.github.io/trace-context-binary/) standard. Since we started
implementing it when this was still a draft, we named the field `elasticapmtraceparent` instead of `traceparent`, and we decided to
wait with the implementation of the `tracestate` field. We chose to avoid hyphens in the field name in order to reduce risk of breaking field name limitations, such as we encountered with some JMS clients.
In order to make sure we are fully aligned, all agents are implementing the
specification described in [this commit](https://github.com/w3c/trace-context-binary/blob/571cafae56360d99c1f233e7df7d0009b44201fe/spec/20-binary-format.md).
