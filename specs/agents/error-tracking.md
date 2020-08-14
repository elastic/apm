## Error/exception tracking

The agent support reporting exceptions/errors. Errors may come in one of two forms:

 - unhandled (or handled and explicitly reported) exceptions/errors
 - log records

Agents should include exception handling in the instrumentation they provide, such that exceptions are reported to the APM Server automatically, without intervention. In addition, hooks into logging libraries may be provided such that logged errors are also sent to the APM Server.

Errors may or may not occur within the context of a transaction or span. If they do, then they will be associated with them by recording the trace ID and transaction or span ID. This enables the APM UI to annotate traces with errors.

### Impact on the `outcome`

Tracking an error that's related to a transaction does not impact its `outcome`.
A transaction might have multiple errors associated to it but still return with a 2xx status code.
Hence, the status code is a more reliable signal for the outcome of the transaction.
This, in turn, means that the `outcome` is always specific to the protocol.