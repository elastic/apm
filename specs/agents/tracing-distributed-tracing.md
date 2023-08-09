## Distributed Tracing

We implement the [W3C standards](https://www.w3.org/TR/trace-context-1/) for
`traceparent` and `tracestate`, both for HTTP headers and binary fields.


### `trace_id`, `parent_id`, and `traceparent`

Our `trace_id`, `parent_id`, and the combined `traceparent` HTTP header follow
the standard established by the
[W3C Trace-Context Spec](https://github.com/w3c/trace-context/blob/main/spec/20-http_request_header_format.md#traceparent-header).

The `traceparent` header is composed of four parts:

 * `version`
 * `trace-id`
 * `parent-id`
 * `trace-flags`

Example:

```
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
             () (______________________________) (______________) ()
             v                 v                        v         v
           Version         Trace-Id                 Parent-Id    Flags
```


#### Version

The `version` is 1 byte (2 hexadecimal digits) representing an 8-bit unsigned
integer. Currently, the `version` will always be `00`.

#### Trace ID

A Trace ID is globally unique, and consists of 128 random bits (like a UUID).
Its string representation is 32 hexadecimal digits.  This is the ID for the
whole distributed trace and stays constant throughout a given trace.

#### Transaction/Span ID, and Parent ID

Each transaction and span object will store the global `trace_id`. If the transaction
is started without an incoming `traceparent` header, then the `trace_id`
should be generated.

Each transaction and span object will have an `id`. This is generated for each
transaction and span, and is 64 random bits (with a string representation of
16 hexadecimal digits).

Each transaction and span object will have a `parent_id`, except for the very
first transaction in the distributed trace. Some agents allow the user to
ensure a parent ID is present on a transaction via an API call. In this case,
if the transaction doesn't have a `parent_id` the agent will generate a new ID
and set it as the `parent_id` for the transaction.

The `parent_id` will be the `id` of the parent transaction/span. For new
transactions with an incoming `traceparent` header, the `parent-id` piece of
the `traceparent` should be used as the `parent_id`.

In addition to the above rules, spans will also have a `transaction_id`,
which is the `id` of the current transaction. While not necessary for
distributed tracing, this inclusion allows for simpler and more performant UI
queries.

Error objects will also include the `trace_id` (optional), an `id` (which in
the case of errors is 128 bits, encoded as 32 hexadecimal digits), a
`transaction_id`, and a `parent_id` (which is the `id` of the transaction or
span that caused the error). If an error occurs outside of the context of a
transaction or span, these fields may be missing.


#### Flags

The W3C traceparent header specifies 8 bits for flags. Currently, only a single
flag (`sampled`) is defined, with the rest reserved for later use. These flags
are recommendations given by the by the caller rather than strict rules to
follow.

##### Sampled

The `sampled` flag is the least significant bit (right-most) and denotes that
the caller may have recorded trace data. If this flag is unset (`0` in the
least significant bit), the agent should not sample the transaction. If this
flag is set (`1` in the least significant bit), the agent should sample the
transaction. The agent may ignore this flag if sampling a transaction would
conflict with another config option, e.g. rate limit.See the
[sampling](tracing-sampling.md) specification for more details.


### `tracestate`

For our own `es` `tracestate` entry we will introduce a `key:value` formatted list of attributes.
This is used to propagate the sampling rate downstream, for example.
See the [sampling](tracing-sampling.md) specification for more details.

The general `tracestate` format is:

    tracestate: es=key:value;key:value...,othervendor=<opaque>

For example:

    tracestate: es=s:0.1,othervendor=<opaque>


#### Validation and length limits

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


### HTTP Headers

Every outgoing request should be intercepted and modified to include both the
`traceparent` and `tracestate` headers, described above.

If an incoming request contains either of the `traceparent` or `tracestate`
headers, they should be propagated throughout the transaction and mutated as
specified above before being set on outgoing requests.

There is an edge case where `tracestate` is present but blank `""` - in this
case, we should not propagate the tracestate header. Propagating the header in
this case can cause downstream receivers of requests from the monitored application
to error if they are excessively sensitive to blank values (blank values are within
spec, but still unexpected)

The `span-id` part of the `traceparent` header should be the `id` of the span
representing the outgoing request. If (and only if) that span is not sampled,
the `span-id` may instead be the `id` of the current transaction.

HTTP/text format should be used for headers wherever possible. Only in cases
where binary fields are necessary (such as in Kafka record headers) should
binary fields be used. (See below for binary fields)


### Binary Fields

Binary fields should only be used where strings are not allowed, such as in
Kafka record headers.

Until the revision of this spec as of January 2023, our implementation relied on the [W3C Binary Trace
Context](https://w3c.github.io/trace-context-binary/) standard.  Hereby, we relied on the specification described in
[this commit](https://github.com/w3c/trace-context-binary/blob/571cafae56360d99c1f233e7df7d0009b44201fe/spec/20-binary-format.md).
We used the proprietary `elasticapmtraceparent` field name for the binary `traceparent`, `tracestate` was ignored.

The available OpenTelemetry instrumentations however went a different route:
 * The binary header spec has been removed and the [issue](https://github.com/open-telemetry/opentelemetry-specification/issues/437) to re-add it has not been touched for a long time.
 * Instead, the OpenTelemetry instrumentations for e.g. Kafka use the textual `traceparent` and `tracestate` formats and encode the values via UTF8 to binary.

To maximize compatibility and not break traces, our agents need to support the textual `traceparent` and `tracestate` via UTF8 encoding as well.
So, the following rules should be used to decode/encode context propagation headers:

Encoding:
 * Add a `elasticapmtraceparent` header with the binary specification above for backwards compatibility
 * Add the textual `traceparent` and `tracestate` headers, encode their values via UTF8

Decoding:
 * If a `traceparent` header is present, use the `traceparent` and `tracestate` headers as textual with UTF8 decoding of the values
 * If no `traceparent` header is present, use the `elasticapmtraceparent` with the binary specification above. `tracestate` is ignored.

Implementation note: The `traceparent` and `tracestate` specifications only allow ASCII characters. Therefore we don't need to use fully fledged UTF8 decoding, instead each byte can directly be interpreted as ASCII character.

This implementation guarantees backwards compatibility with our older agents and compatibility with current OpenTelemetry instrumentations.
We will eventually remove the `elasticapmtraceparent` entirely as soon as we can safely assume that most users have already upgraded all their agents.

### Baggage

To propagate distributed context, we implement the [W3C Baggage](https://www.w3.org/TR/baggage/) specification.

Agents MUST parse, validate, and attach the `baggage` header according [to the W3C specification](https://www.w3.org/TR/baggage/).

In addition to the W3C specification, agents also SHOULD offer users 2 ways to use the values propagated via baggage:
- Offer a Baggage API to manually manipulate and read baggage values - this is preferable the OpenTelemetry API.
- Offer baggage related configuration to automatically store baggage values on events.

#### Baggage API

Agents SHOULD integrate with the existing OpenTelemetry API. Users should be able to use the OpenTelemetry API to interact with the baggage maintained by the agent. The primary way to interact with baggage SHOULD be the OpenTelemetry API.

In case using the OpenTelemetry API isn't feasible in a given language, the agent SHOULD extend the proprietary agent API to interact with baggage.

This API MUST offer the following functionalities:
- Adding a new baggage item
- Changing an existing baggage item
- Removing an existing baggage item
- Reading a specific baggage item
- Reading all baggage items

#### Baggage related configuration

The following configuration enables users to automatically store baggage items on a given event without any code change. Baggage items with matching keys are stored in `otel.attributes`, except on errors, since there is no `otel.attributes` on errors. Keys of baggage items lifted by the agent from baggage into attributes/labels MUST be prefixed with `baggage.`.

`baggage_to_attach` configuration

A list of baggage keys which are automatically attached to the current event (transaction, span, or error). When the event is created, the agent iterates through all baggage items currently available and stores the ones with keys that match one of the items from the configured wildcard matcher list on the newly created event with a prefix `baggage.`. In case of transactions and spans, the agent MUST send this data in `otel.attributes`, in case of errors the agent MUST send the data in labels.

|                |   |
|----------------|---|
| Type           | `List<`[`WildcardMatcher`](../../tests/agents/json-specs/wildcard_matcher_tests.json)`>` |
| Default        | `*`    |
| Dynamic        | `true` |
| Central config | `true` |

### Legacy HTTP Header Name

Some agents support the legacy header name `elastic-apm-traceparent`. This name
was used while the W3C standard was being finalized, to avoid any
backwards-compatibility issues. New agents do not need to support this legacy
name. Because `tracestate` was not implemented until the standard was
finalized, no legacy names exist for this field.

Agents that do support the legacy header MUST give precedence to the `traceparent` header if both are present.
