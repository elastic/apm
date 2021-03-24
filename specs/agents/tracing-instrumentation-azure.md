## Azure services spans

We describe how to instrument some of Azure's services in this document.
Some of the services can use existing specs. When there are differences or additions, they have been noted below.

### Azure Service Bus

Azure Service Bus is a message broker service. The [messaging spec](tracing-instrumentation-messaging.md) can 
be used for instrumenting Azure Service Bus, but the follow specifications supersede those of the messaging spec.

#### Typing

- Spans: 
  - `span.subtype`: `azureservicebus` 

#### Additional actions

Azure Service Bus supports actions that should be traced in addition to `SEND` and `RECEIVE`:

- `SCHEDULE`

  Message published to the bus, but not visible until some later point.

- `RECEIVEDEFERRED`

  Message received from the bus, but marked as deferred on the bus, then later retrieved with receive deferred.

#### Naming

Messages can be sent to queues and topics, and can be received from queues and topic subscriptions.

Transaction and span names should* follow these patterns:

For send and schedule,

`AzureServiceBus SEND|SCHEDULE to <QUEUE-NAME>|<TOPIC-NAME>`

For receive and receive deferred,

`AzureServiceBus RECEIVE|RECEIVEDEFERRED from <QUEUE-NAME>|<TOPIC-NAME>/Subscriptions/<SUBSCRIPTION-NAME>`
