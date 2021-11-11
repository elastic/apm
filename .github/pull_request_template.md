# Agent spec PR checklist

<!--
Delete all of this if the PR is not changing the agent spec.
Delete sections that don't apply to this PR.
If a specific checkbox doesn't apply, ~strike through~ and check it instead of deleting it.
-->

## For small enhancements of existing specs

- [ ] Create PR as draft
- [ ] Approval by at least one other agent
- [ ] Mark as Ready for Review
- [ ] Merge after 2 days passed without objections

## For new specs and bigger enhancements

- May the instrumentation collect sensitive information, such as secrets or PII (ex. in headers)?
  - [ ] Yes
    - [ ] Add a section to the spec how agents should apply sanitization (such as `sanitize_field_names`)
  - [ ] No
- [ ] Discussion/meta issue: #
- [ ] Create PR as draft
- [ ] Approval by at least one other agent
- [ ] Mark as Ready for Review
  - Remove PM approval if impact on product is negligible
  - Remove RUM approval if it's not relevant for RUM
- [ ] Approved by at least 2 agents + PM (if relevant)
- [ ] Merge after 7 days passed without objections
- [ ] [https://gprom.app.elstc.co/issue-creator](Create implementation issues)
- [ ] [Create a status table](https://gprom.app.elstc.co/status/7.16) and add it to the meta issue
