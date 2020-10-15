### Distributed Tracing

We implement the [W3C standards](https://www.w3.org/TR/trace-context-1/) for
`traceparent` and `tracestate`, both for HTTP headers and binary fields.


#### Tracestate

For our own `es` `tracestate` entry we will introduce a `key:value` formatted list of attributes.
This is used to propagate the sampling rate downstream, for example.
See the [sampling](tracing-sampling.md) specification for more details.

The general `tracestate` format is:

    tracestate: es=key:value;key:value...,othervendor=<opaque>

For example:

    tracestate: es=s:0.1,othervendor=<opaque>


##### Validation and length limits

The [`tracestate`](https://www.w3.org/TR/trace-context/#tracestate-header)
specification lists a number of validation rules.
In addition to that,
there are specific rules for the attributes under the `es` entry.

Agents MUST implement these validation rules when mutating `tracestate`:

- Vendor keys (such as `es`) have a maximum size of 256 chars.
- Vendor keys MUST begin with a lowercase letter or a digit,
  and can only contain lowercase letters (`a-z`),
  digits (`0-9`), underscores (`_`), dashes (`-`), asterisks (`*`),
  and forward slashes (`/`).
- Vendor values have a maximum size of 256 chars.
- Vendor values may only contain ASCII RFC0020 characters (i.e., the range `0x20` to `0x7E`) except comma `,` and `=`.
- In addition to the above limitations, the keys and values used in the `es` entry must not contain the characters `:` and `;`.
- If adding another key/value pair to the `es` entry would exceed the limit of
  256 chars (including separator characters `:` and `;`), that key/value pair
  MUST be ignored by agents.

Note that we will currently only ever populate an `es` `tracestate` entry at the trace root.
It is not strictly necessary to validate `tracestate` in its entirety when received downstream.
Instead, downstream agents may opt to only parse the `es` entry and skip validation of other vendors' entries.
This means that the vendor key validations are only relevant if an agent adds
its own non-`es` keys to tracestate

In addition, we do not enforce the 32-entry limit for vendor entries in
`tracestate`. Doing so would cripple our ability to use `tracestate` for our
own purposes, arbitrarily. Removing other entries to make way for our own
would also cause unexpected behavior. In any case, this situation should be
rare and we feel comfortable ignoring the validation rules in this case.


#### Binary Fields

Our implementation relies on the [W3C Binary Trace
Context](https://w3c.github.io/trace-context-binary/) standard.  In order to
make sure we are fully aligned, all agents are implementing the specification described in
[this commit](https://github.com/w3c/trace-context-binary/blob/571cafae56360d99c1f233e7df7d0009b44201fe/spec/20-binary-format.md).

Binary fields should only be used where strings are not allowed, such as in
Kafka record headers.


#### Legacy HTTP Headers/Binary Fields

Some agents support the legacy header name `elastic-apm-traceparent` and the
binary field name `elasticapmtraceparent`. These names were used while the W3C
standard was being finalized, to avoid any backwards-compatibility issues. New
agents do not need to support these legacy names. Because `tracestate` was
not implemented until the standar was finalized, no legacy names exist for
this field.

