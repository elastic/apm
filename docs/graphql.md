# GraphQL transactions and spans

**NB:** This document is a work in progress.

Our current approach of splitting and grouping transaction by HTTP method and path fits perfectly for REST-style APIs and the like.

With a GraphQL approach, the client always requests the same endpoint. This means wildly different queries and mutations all will end up in the same transaction group.

To better support GraphQL servers we need to find another way to tell the queries apart.

Example GraphQL query:

```graphql
{
  user {
    id
    name
    comments {
      body
    }
  }
}
```

**Note:** The Node.js agent already supports GraphQL. This spec is written with that in mind but not necessarily with its implementation as a target result.

## Prefix

To distinguish GraphQL spans from others we prefix them with `GraphQL:`. A span with just the name `User` will be hard to recognise from just that name, whereas `GraphQL:User` is easy to recognise.

## Operation Name

It is common (and [recommended](https://graphql.org/learn/queries/#operation-name)) to provide an _Operation Name_ for queries. Here for example `UserWithName`:

```graphql
query UserWithComments {
  user {
    id
    name
    comments {
      body
    }
  }
}
```

The point of these are to provide an easy way for the developers, when things go wrong, to pinpoint where exactly they did so.

This name is available on the server too and serves as a great distinguishing key.

Span name examples:
- `GraphQL:UserWithComments`
- `GraphQL:UpdateUser`

## Multiple endpoints

An app may serve multiple GraphQL endpoints. To tell them apart we can include the path in the transaction name.

- `GraphQL:UserWithComments (/api/graphql)`

I'm not sure this is a common thing to do, so perhaps this could be an opt-in option, like `graphql_postfix_path: true`.

## Anonymous queries

An Operation Name isn't required. When one isn't provided it's hard for us to tell apart the queries.

Some clients generate `id`s from hashing the contents of the query (see [apollo-tooling](https://github.com/apollographql/apollo-tooling/blob/1dfd737eaf85b89b2cfb13913342e091e3c03d18/packages/apollo-codegen-core/src/compiler/visitors/generateOperationId.ts#L5)). We could choose to do something similar.

A problem with this approach is that the user of the APM UI has no way to recognise queries in the transactions list before clicking through.

Another approach is to simply label them `[anonymous query]` or something similar.

A problem with _that_ approach is that the contents and thereby the relevant db queries and other sub-span actions that the server might do while resolving these queries may be wildly different making it hard to provide a _true_ sample waterfall.
 These two examples for example will look the same for the top-level GraphQL spans but will represent significantly different workloads.

```
[- anonymous graphql span --------------]
  [- 1,000x SELECT * ---------------]
    [- 1,000 more SELECT * -]

[- anonymous graphql span --------------]
  [- SELECT id FROM users WHERE id=? -]
```

We could consider _muting_ or ignoring all sub-spans to anonymous GraphQL queries and choose to rather show nothing than potentially wrong information.

Span name examples:
- `GraphQL:ka8kadf8233kxcsc2929384384kdkdkc8383…`
- `GraphQL:[anonymous]`

## Batching/Multiplexing queries

Some clients allow batching queries (see for example [apollo-link-batch-http](https://www.apollographql.com/docs/link/links/batch-http/#gatsby-focus-wrapper)

So far it makes sense to update transaction names based on the span names. Essentially, in the best case, let the transactions be named after the Operation Names.

However with multiple queries per HTTP request this wont work.

Combining span names with `+` could work.

Span name examples:
- `GraphQL:UserWithComments+PostWithSiblings+MoreThings`
