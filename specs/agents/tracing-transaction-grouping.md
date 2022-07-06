## Transaction Grouping

Even though agents should choose a transaction name that has a reasonable cardinality,
they can't always guarantee that.
For example,
when the auto-instrumentation of a job scheduling framework sets the transaction name to the name of the instrumented job,
the agent has no control over the job name itself.
While usually the job name is expected to have low cardinality,
users might set dynamic parts as part of the job name, such as a UUID.

In order to give users an option to group transactions whose name contain dynamic parts that don't require code changes,
agents MAY implement the following configuration option:

### `transaction_name_groups` configuration

With this option,
you can group transaction names that contain dynamic parts with a wildcard expression.
For example,
the pattern `GET /user/*/cart` would consolidate transactions,
such as `GET /users/42/cart` and `GET /users/73/cart` into a single transaction name `GET /users/*/cart`, hence reducing the transaction name cardinality.
The first matching expression wins, so make sure to place more specific expressions before more generic ones, for example: `GET /users/*/cart, GET /users/*`.

|                |                                                                                          |
|----------------|------------------------------------------------------------------------------------------|
| Type           | `List<`[`WildcardMatcher`](../../tests/agents/json-specs/wildcard_matcher_tests.json)`>` |
| Default        | `<none>`                                                                                 |
| Dynamic        | `true`                                                                                   |
| Central config | `true`                                                                                   |

The `url_groups` option that the Java and PHP agent offered is deprecated in favor of `transaction_name_groups`.
### When to apply the grouping

The grouping can be applied either every time the transaction name is set, or lazily, when the transaction name is read.

It's not sufficient to only apply the grouping when the transaction ends.
That's because when an error is tracked, the transaction name is copied to the error object.
See also [the error spec](error-tracking.md)

Agents MUST also ensure that the grouping is applied before breakdown metrics are reported.
