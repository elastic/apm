#### Transaction sampling

To reduce processing and storage overhead, transactions may be "sampled". Currently sampling has the effect of limiting the amount of data we capture for transactions: for non-sampled transactions instrumentation should not record context, nor should any spans be captured. The default graphs in the APM UI will utilise the transaction properties available for both sampled and non-sampled transactions.

By default all transactions will be sampled. Agents can be configured to sample probabilistically, by specifying a sampling
probability in the range \[0,1\] using the configuration `ELASTIC_APM_TRANSACTION_SAMPLE_RATE`. For example:

 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0` means no transactions will be sampled
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=1` means all transactions will be sampled (the default)
 - `ELASTIC_APM_TRANSACTION_SAMPLE_RATE=0.5` means approximately 50% of transactions will be sampled

If a transaction is not sampled, you should set the `sampled: false` property and omit collecting `spans` and `context`.
