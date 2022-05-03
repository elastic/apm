## OpenTelemetry API (Tracing)

[OpenTelemetry](https://opentelemetry.io) (OTel in short) provides a vendor-neutral API that allows to capture tracing, logs and metrics data.

Agents MAY provide a bridge implementation of OpenTelemetry Tracing API following this specification.
When available, implementation MUST be configurable and should be disabled by default when marked as `experimental`.

The bridge implementation relies on APM Server version 7.16 or later. Agents SHOULD recommend this minimum version to users in bridge documentation.

Bridging here means that for each OTel span created with the API, a native span/transaction will be created and sent to APM server.

### User experience

On a high-level, from the perspective of the application code, using the OTel bridge should not differ from using the
OTel API for tracing. See [limitations](#limitations) below for details on the currently unsupported OTel features.
For tracing the support should include:
- creating spans with attributes
- context propagation
- capturing errors

The aim of the bridge is to allow any application/library that is instrumented with OTel API to capture OTel spans to
seamlessly delegate to Elastic APM span/transactions. Also, it provides a vendor-neutral alternative to any existing
manual agent API with similar features.

One major difference though is that since the implementation of OTel API will be delegated to Elastic APM agent, the
whole OTel configuration that might be present in the application code (OTel processor pipeline) or deployment
(env. variables) will be ignored.

### Limitations

The OTel API/specification goes beyond tracing, as a result, the following OTel features are not supported:
- metrics
- logs
- span events
- span link *attributes*

### Spans and Transactions

OTel only defines Spans, whereas Elastic APM relies on both Spans and Transactions.
OTel allows users to provide the _remote context_ when creating a span, which is equivalent to providing a parent to a transaction or span,
it also allows to provide a (local) parent span.

As a result, when creating Spans through OTel API with a bridge, agents must implement the following algorithm:

```javascript
// otel_span contains the properties set through the OTel API
span_or_transaction = null;
if (otel_span.remote_context != null) {
    span_or_transaction = createTransactionWithParent(otel_span.remote_context);
} else if (otel_span.parent == null) {
    span_or_transaction = createRootTransaction();
} else {
    span_or_transaction = createSpanWithParent(otel_span.parent);
}
```

### Span Kind

OTel spans have an `SpanKind` property ([specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#spankind)) which is close but not strictly equivalent to our definition of spans and transactions.

For both transactions and spans, an optional `otel.span_kind` property will be provided by agents when set through
the OTel API.
This value should be stored into Elasticsearch documents to preserve OTel semantics and help future OTel integration.

Possible values are `CLIENT`, `SERVER`, `PRODUCER`, `CONSUMER` and `INTERNAL`, refer to [specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#spankind) for details on semantics.

By default, OTel spans have their `SpanKind` set to `INTERNAL` by OTel API implementation, so it is assumed to always be provided when using the bridge.

For existing agents without OTel bridge or for data captured without the bridge, the APM server has to infer the value of `otel.span_kind` with the  following algorithm:

```javascript
span_kind = null;
if (isTransaction(item)) {
    if (item.type == "messaging") {
        span_kind = "CONSUMER";
    } else if (item.type == "request") {
        span_kind = "SERVER";
    }
} else {
    // span
    if (item.type == "external" || item.type == "storage" || item.type == "db") {
        span_kind = "CLIENT";
    }
}

if (span_kind == null) {
    span_kind = "INTERNAL";
}

```

While being optional, inferring the value of `otel.span_kind` helps to keep the data model closer to the OTel specification, even if the original data was sent using the native agent protocol.

### Span status

OTel spans have a [Status](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#set-status)
field to indicate the status of the underlying task they represent.

When the [Set Status](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#set-status) on OTel API is used, we can map it directly to `span.outcome`:
- OK => Success
- Error => Failure
- Unset (default) => Unknown

However, when not provided explicitly agents can infer the outcome from the presence of a reported error.
This behavior is not expected with OTel API with status, thus bridged spans/transactions should NOT have their outcome
altered by reporting (or lack of reporting) of an error. Here the behavior should be identical to when the end-user provides
the outcome explicitly and thus have higher priority over the inferred value.

### Attributes mapping

OTel relies on key-value pairs for span attributes.
Keys and values are protocol-specific and are defined in [semantic convention](https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions) specification.

In order to minimize the mapping complexity in agents, most of the mapping between OTel attributes and agent protocol will be delegated to APM server:
- All OTel span attributes should be captured as-is and written to agent protocol.
- APM server will handle the mapping between OTel attributes and their native transaction/spans equivalents
- Some native span/transaction attributes will still require mapping within agents for [compatibility with existing features](#compatibility-mapping)

OpenTelemetry attributes should be stored in `otel.attributes` as a flat key-value pair mapping added to `span` and `transaction` objects:
```json
{
  // [...] other span/transaction attributes
  "otel": {
    "span_kind": "CLIENT",
    "attributes": {
      "db.system": "mysql",
      "db.statement": "SELECT * from table_1"
    }
  }
}
```

Starting from version 7.16 onwards, APM server must provide a mapping that is equivalent to the native OpenTelemetry Protocol (OTLP) intake for the
fields provided in `otel.attributes`.

When sending data to APM server version before 7.16, agents MAY use span and transaction labels as fallback to store OTel attributes to avoid dropping information.

### Compatibility mapping

Agents should ensure compatibility with the following features:
- breakdown metrics
- [dropped spans statistics](handling-huge-traces/tracing-spans-dropped-stats.md)
- [compressed spans](handling-huge-traces/tracing-spans-compress.md)

As a consequence, agents must provide values for the following attributes:
- `transaction.name` or `span.name` : value directly provided by OTel API
- `transaction.type` : see inference algorithm below
- `span.type` and `span.subtype` : see inference algorithm below
- `span.destination.service.resource` : see inference algorithm below

#### Transaction type

```javascript
a = transation.otel.attributes;
span_kind = transaction.otel_span_kind;
isRpc = a['rpc.system'] !== undefined;
isHttp = a['http.url'] !== undefined || a['http.scheme'] !== undefined;
isMessaging = a['messaging.system'] !== undefined;
if (span_kind == 'SERVER' && (isRpc || isHttp)) {
    type = 'request';
} else if (span_kind == 'CONSUMER' && isMessaging) {
    type = 'messaging';
} else {
    type = 'unknown';
}
```

#### Span type, sub-type and destination service resource

```javascript
a = span.otel.attributes;
type = undefined;
subtype = undefined;
resource = undefined;

httpPortFromScheme = function (scheme) {
    if ('http' == scheme) {
        return 80;
    } else if ('https' == scheme) {
        return 443;
    }
    return -1;
}

// extracts 'host' or 'host:port' from URL
parseNetName = function (url) {
    var u = new URL(url); // https://developer.mozilla.org/en-US/docs/Web/API/URL
    if (u.port != '') {
        return u.hostname; // host:port already in URL
    } else {
        var port = httpPortFromScheme(u.protocol.substring(0, u.protocol.length - 1));
        return port > 0 ? u.host + ':'+ port : u.host;
    }
}

peerPort = a['net.peer.port'];
netName = a['net.peer.name'] || a['net.peer.ip'];

if (netName && peerPort > 0) {
    netName += ':';
    netName += peerPort;
}

if (a['db.system']) {
    type = 'db'
    subtype = a['db.system'];
    resource = netName || subtype;
    if (a['db.name']) {
        resource += '/'
        resource += a['db.name'];
    }

} else if (a['messaging.system']) {
    type = 'messaging';
    subtype = a['messaging.system'];

    if (!netName && a['messaging.url']) {
        netName = parseNetName(a['messaging.url']);
    }
    resource = netName || subtype;
    if (a['messaging.destination']) {
        resource += '/';
        resource += a['messaging.destination'];
    }

} else if (a['rpc.system']) {
    type = 'external';
    subtype = a['rpc.system'];
    resource = netName || subtype;
    if (a['rpc.service']) {
        resource += '/';
        resource += a['rpc.service'];
    }

} else if (a['http.url'] || a['http.scheme']) {
    type = 'external';
    subtype = 'http';

    if (a['http.host'] && a['http.scheme']) {
        resource = a['http.host'] + ':' + httpPortFromScheme(a['http.scheme']);
    } else if (a['http.url']) {
        resource = parseNetName(a['http.url']);
    }
}

if (type === undefined) {
    if (span.otel.span_kind == 'INTERNAL') {
        type = 'app';
        subtype = 'internal';
    } else {
        type = 'unknown';
    }
}
span.type = type;
span.subtype = subtype;
span.destination.service.resource = resource;
```

### Active Spans and Context

When possible, bridge implementation MUST ensure proper interoperability between Elastic transactions/spans and OTel spans when
used from their respective APIs:
- After activating an Elastic span via the agent's API, the [`Context`] returned via the [get current context API] should contain that Elastic span
- When an OTel context is [attached] (aka activated), the [get current context API] should return the same [`Context`] instance.
- Starting an OTel span in the scope of an active Elastic span should make the OTel span a child of the Elastic span.
- Starting an Elastic span in the scope of an active OTel span should make the Elastic span a child of the OTel span.

[`Context`]: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/context/context.md
[attached]: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/context/context.md#attach-context
[get current context API]: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/context/context.md#get-current-context

Both OTel and our agents have their own definition of what "active context" is, for example:
- Java Agent: Elastic active context is implemented as a thread-local stack
- Java OTel API: active context is implemented as a key-value map propagated through thread local

In order to avoid potentially complex and tedious synchronization issues between OTel and our existing agent
implementations, the bridge implementation SHOULD provide an abstraction to have a single "active context" storage.
