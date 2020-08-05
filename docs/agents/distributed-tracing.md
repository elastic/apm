# Distributed Tracing

We implement the W3C standards, both for HTTP headers and binary fields.

To test compatibility with the standard,
agents MUST validate against the w3c [test harness](https://github.com/w3c/trace-context/blob/master/test/test_data.json).

## Http Headers

Our implementation relies on the [W3C Trace Context](https://www.w3.org/TR/trace-context-1/) standard. Until this standard became final,
we used the header name `elastic-apm-traceparent` and we did not support `tracestate`. Soon after the standard became official, we
started to fully align with it. For backward compatibility reasons, this was done in phases, so that the first step was to look for both
`traceparent` headers in incoming requests (meaning - both `elastic-apm-traceparent` and `traceparent`) and sending both `traceparent` headers in outgoing requests (with the exception of the RUM agent,
due to CORS). [Issue #71](https://github.com/elastic/apm/issues/71) describes this in more detail, as well as tracking implementation
in the different agents.
New agents may decide whether to support both `traceparent` headers (so to be compatible with older agent versions) or only the formal W3C
header.

## Tracestate

For our own `elastic` `tracestate` entry we will introduce a `key:value` formatted list of attributes.
This is used to propagate the sample weight downstream, for example.
See the [sampling](sampling.md) specification for more details.

The general `tracestate` format is:

    tracestate: elastic=key:value;key:value...,othervendor=<opaque>

For example:

    tracestate: elastic=w:5,othervendor=<opaque>


### Validation and length limits

The [`tracestate`](https://www.w3.org/TR/trace-context/#tracestate-header)
specification lists a number of validation rules.
In addition to that,
there are specific rules for the attributes under the `elastic` entry.

Agents MUST implement these validation rules:

- The `tracestate` field may contain a maximum of 32 entries.
  An entry consists of a vendor key, and an opaque vendor value.
- Vendor keys (such as `elastic`) have a maximum size of 256 chars.
- Vendor keys MUST begin with a lowercase letter or a digit,
  and can only contain lowercase letters (`a-z`),
  digits (`0-9`), underscores (`_`), dashes (`-`), asterisks (`*`),
  and forward slashes (`/`).
- Vendor values have a maximum size of 256 chars.
- Vendor values may only contain ASCII RFC0020 characters (i.e., the range `0x20` to `0x7E`) except comma `,` and `=`.
- In addition to the above limitations, the keys and values used in the `elastic` entry must not contain the characters `:` and `;`.
- If adding another key/value pair to the `elastic` entry would exceed the limit of 256 chars,
  that key/value pair MUST be ignored by agents.
  The key/value and entry separators `:` and `;` have to be considered as well.

## Binary Fields

Our implementation relies on the [W3C Binary Trace Context](https://w3c.github.io/trace-context-binary/) standard. Since we started
implementing it when this was still a draft, we named the field `elasticapmtraceparent` instead of `traceparent`, and we decided to
wait with the implementation of the `tracestate` field. We chose to avoid hyphens in the field name in order to reduce risk of breaking field name limitations, such as we encountered with some JMS clients.
In order to make sure we are fully aligned, all agents are implementing the
specification described in [this commit](https://github.com/w3c/trace-context-binary/blob/571cafae56360d99c1f233e7df7d0009b44201fe/spec/20-binary-format.md).
