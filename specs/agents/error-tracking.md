## Error/exception tracking

The agent support reporting exceptions/errors. Errors may come in one of two forms:

 - unhandled (or handled and explicitly reported) exceptions/errors
 - log records

Agents should include exception handling in the instrumentation they provide, such that exceptions are reported to the APM Server automatically, without intervention. In addition, hooks into logging libraries may be provided such that logged errors are also sent to the APM Server.

Error objects will also include the `trace_id` (optional), an `id` (which in
the case of errors is 128 bits, encoded as 32 hexadecimal digits), a
`transaction_id`, and a `parent_id` (which is the `id` of the transaction or
span that caused the error). If an error occurs outside of the context of a
transaction or span, these fields may be missing.

### Impact on the `outcome`

Tracking an error that's related to a transaction does not impact its `outcome`.
A transaction might have multiple errors associated to it but still return with a 2xx status code.
Hence, the status code is a more reliable signal for the outcome of the transaction.
This, in turn, means that the `outcome` is always specific to the protocol.
