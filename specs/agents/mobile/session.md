# Session 

### Overview
A `session` is a collection of `logs`, `events`, `transactions` and `spans` (`LETS`) associated with a specific device within a specific period of time. 
A `session` is represented by a unique identify that is attached to `LETS` as an attribute. 

The primary purpose of `sessions` are to provide insight into the series of user actions or events that lead up to a critical error or crash. Sessions also provide a means to quantify application usage.

### How a session operates
- All `LETS` will have a `session` identifier attached as an attribute using the name `session.id`.
- After a period of timeout, the `session` identifier will be refreshed.
- The timeout period will be restarted when any `LETS` is recorded.  


#### The session timeout period can be customized. 
Default session timeout should be 30 minutes. This should only be done when the agent is configured, and shouldn't be updated in the middle of a session.

#### Max session length
Sessions will be limited to a maximum length of four (4) hours. This limitation will be implemented in the mobile agent.
