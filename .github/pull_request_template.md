<!--
Agent spec PR checklist

Delete all of this if the PR is not changing the agent spec.
Delete sections that don't apply to this PR.
If a specific checkbox doesn't apply, ~strike through~ and check it instead of deleting it.
-->

<!--
Use this section if the spec requires changes in at most two agents.

Examples:
- Typos or clarifications without semantic changes
- Changes in a spec before it has been implemented
- Features that are only implemented in two agents
-->

- [ ] Create PR as draft
- [ ] Approval by at least one other agent
- [ ] Mark as Ready for Review (automatically requests reviews from all agents and PM via [`CODEOWNERS`](https://github.com/elastic/apm/tree/main/.github/CODEOWNERS))
  - Remove PM from reviewers if impact on product is negligible
  - Remove agents from reviewers if the change is not relevant for them
- [ ] Merge after 2 business days passed without objections \
      To auto-merge the PR, add <code>/</code>`schedule YYYY-MM-DD` to the PR description.

<!--
Use this section if the spec requires changes in more than two agents.

This extended template ensures that we have a meta issue and tracking issues so that we don't forget about implementing the changes in all affected agents.
-->

- May the instrumentation collect sensitive information, such as secrets or PII (ex. in headers)?
  - [ ] Yes
    - [ ] Add a section to the spec how agents should apply sanitization (such as `sanitize_field_names`)
  - [ ] No
    - [ ] Why?
  - [ ] n/a
- [ ] Link to meta issue: # <!-- create a meta issue if it does not exist yet -->
- [ ] Create PR as draft
- [ ] Approval by at least one other agent
- [ ] Mark as Ready for Review (automatically requests reviews from all agents and PM via [`CODEOWNERS`](https://github.com/elastic/apm/tree/main/.github/CODEOWNERS))
  - Remove PM from reviewers if impact on product is negligible
  - Remove agents from reviewers if the change is not relevant for them
- [ ] Approved by at least 2 agents + PM (if relevant)
- [ ] Merge after 7 days passed without objections
- [ ] [Create implementation issues](https://gprom.app.elstc.co/issue-creator) (ideally add a milestone)
- [ ] [Create a status table](https://gprom.app.elstc.co/status/7.16) and add it to the meta issue
