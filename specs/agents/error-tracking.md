## Error/exception tracking

The agent support reporting exceptions/errors. Errors may come in one of two forms:

 - unhandled (or handled and explicitly reported) exceptions/errors
 - log records

Agents should include exception handling in the instrumentation they provide, such that exceptions are reported to the APM Server automatically, without intervention. In addition, hooks into logging libraries may be provided such that logged errors are also sent to the APM Server.

Error properties
* `id` (which in the case of errors is 128 bits, encoded as 32 hexadecimal digits)

Additinoal properties when the error happens within the context of a transaction
* `trace_id`
* `transaction_id`
* `parent_id` (which is the `id` of the transaction or span that caused the error).
* `transaction.sampled`
* `transaction.name`†
* `transaction.type`†

† These properties may change during the lifetime of a transaction, for example if a user explicitly sets the transaction name after an error has been captured.
It is a known and accepted limitation that these properties are not always consistent with the transaction.
Agents MUST NOT buffer errors to ensure consistency as this comes at the expense of increased memory overhead.

### Impact on the `outcome`

Tracking an error that's related to a transaction does not impact its `outcome`.
A transaction might have multiple errors associated to it but still return with a 2xx status code.
Hence, the status code is a more reliable signal for the outcome of the transaction.
This, in turn, means that the `outcome` is always specific to the protocol.
