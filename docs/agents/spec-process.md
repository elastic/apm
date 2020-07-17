Instead of issue descriptions acting as specs, I'd like to do this in the form of a PR which adds a new file to https://github.com/elastic/apm/tree/master/docs (or /specs?).

This has the following advantages:

- Ensures we have an up-to-date [spec](https://www.joelonsoftware.com/2000/08/09/the-joel-test-12-steps-to-better-code/) for agents
- Easier to keep track of what the current state of the proposal is
- Comments to a specific sentence of the spec can be made inline, just like in code reviews
- If there are changes or amendments to a spec later on, a PR to an existing spec is much cleaner than having to track down all preceding issues to find out what the current state is.
- Easier to get a new agent (in-house or community) started


But there can certainly be cases where things are so unclear that it's not reasonable to even do a rough initial version of a spec PR. In those cases, a regular discussion issue would still be the way to go. As soon as things get a bit clearer, there should be a draft spec PR, however. Discussion issues should not have votes/agent checkboxes.
It's not expected that all agents participate in the initial discussions, although everyone is invited to do so.

- agents discussion issue 
- Draft PR 
- Approval by at least one other agent 
- Ready for Review. This automatically requests review from all agents due to CODEOWNERS
- After a quorum of agents has approved, others have 1w to veto by requesting changes
- PR can be merged by the author of the PR
