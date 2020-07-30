Every change that affects more than one agent should be initiated via a change to the specification rather than creating a cross-agent issue.

## Process

1. Agents discussion issue \
  If there's a lot of uncertainty about what the proposal is,
  a discussion issue should be created.
  In doubt, lean towards not creating a discussion issue and start with a draft PR.
  Discussion issues should not have votes/agent checkboxes.
  It's not expected that all agents participate in the initial discussions, although everyone is invited to do so.
1. Draft PR \
  It's fine if the first draft of the spec change even if details are unclear and need discussion.
  The PR should include which agents are affected by this change.
  Specifically, it should always be clear whether the RUM agent is affected by this.
  This doesn't have to be determined yet when creating the draft PR,
  but it is required before marking the PR as `Ready for Review`.
1. Approval by at least one other agent \
  This makes sure the change makes sense for not just one agent.
  This doesn't ping all agent teams yet,
  which only happens in the next step.
  Of course,
  every agent is more than welcome to contribute at any point in this process,
  but they are not expected to actively keep track if it.
1. Ready for Review \
  This automatically requests review from all agents due to the [`CODEOWNERS`](https://github.com/elastic/apm/tree/master/.github/CODEOWNERS) file.
  After a quorum of agents has approved, others have 1 week to veto by requesting changes.
  If the proposed changes are likely to be problematic for a certain agent,
  an approval from that agent is mandatory.
1. Prioritization \
  At any point in time,
  but before merging the PR,
  the priority should be determined.
  That happens in collaboration with devs and leads.
  It's recommended to do that sooner rather than later
  so that we don't spend a lot of time discussing a feature that's not going to be prioritized.
  As a result of the prioritization,
  the PR gets assigned to a milestone,
  reflecting the stack release version this feature should be implemented by all agents.
  If some agents are not going to implement the change by that stack release version,
  or if there are no immediate plans to implement the change at all,
  a comment should be made on the PR.
1. PR can be merged by the author of the PR \
  Three business days before merging, there should be a last call for objections.
1. The author of the PR creates an issue in each agent's repo \
  They make sure the issues are assigned to a stack release milestone,
  based on the milestone of the spec PR.
  Agent teams can still change the milestone if priorities shift.
  However, they should let their team lead know.

## Advantages

- Ensures we have an up-to-date [spec](https://www.joelonsoftware.com/2000/08/09/the-joel-test-12-steps-to-better-code/) for agents.
- Easier to keep track of what the current state of the proposal is.
- Comments to a specific sentence of the spec can be made inline,
  just like in code reviews.
- If there are changes or amendments to a spec later on,
  a PR to an existing spec is much cleaner than having to track down all preceding issues to find out what the current state is.
- Easier to get a new agent (in-house or community) started.
