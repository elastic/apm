Feature: Outcome

  Background: An agent with default configuration
    Given an agent

  # ---- user set outcome

  Scenario: User set outcome on span has priority over instrumentation
    Given an active span
    And user sets span outcome to 'failure'
    When span terminates with outcome 'success'
    Then span outcome is 'failure'

  Scenario: User set outcome on transaction has priority over instrumentation
    Given an active transaction
    And user sets transaction outcome to 'unknown'
    When transaction terminates with outcome 'failure'
    Then transaction outcome is 'unknown'

  # ---- span & transaction outcome from reported errors

  Scenario: span with error
    Given an active span
    When span terminates with an error
    Then span outcome is 'failure'

  Scenario: span without error
    Given an active span
    When span terminates
    Then span outcome is 'success'

  Scenario: transaction with error
    Given an active transaction
    When transaction terminates with an error
    Then transaction outcome is 'failure'

  Scenario: transaction without error
    Given an active transaction
    When transaction terminates
    Then transaction outcome is 'success'

  # ---- HTTP

  @http
  Scenario Outline: HTTP transaction and span outcome
    Given an active HTTP transaction with <status> response code
    When transaction terminates
    Then transaction outcome is "<server>"
    Given an active HTTP span with <status> response code
    When span terminates
    Then span outcome is "<client>"
    Examples:
      | status | client  | server  |
      | 100    | success | success |
      | 200    | success | success |
      | 300    | success | success |
      | 400    | failure | success |
      | 404    | failure | success |
      | 500    | failure | failure |
      | -1     | failure | failure |
      # last row with negative status represents the case where the status is not available
      # for example when an exception/error is thrown without status (IO error, redirect loop, ...)

  # ---- gRPC

  # reference spec : https://github.com/grpc/grpc/blob/master/doc/statuscodes.md

  @grpc
  Scenario Outline: gRPC transaction and span outcome
    Given an active gRPC transaction with '<status>' status
    When transaction terminates
    Then transaction outcome is "<server>"
    Given an active gRPC span with '<status>' status
    When span terminates
    Then span outcome is "<client>"
    Examples:
      | status              | client  | server  |
      | OK                  | success | success |
      | CANCELLED           | failure | success |
      | UNKNOWN             | failure | failure |
      | INVALID_ARGUMENT    | failure | success |
      | DEADLINE_EXCEEDED   | failure | failure |
      | NOT_FOUND           | failure | success |
      | ALREADY_EXISTS      | failure | success |
      | PERMISSION_DENIED   | failure | success |
      | RESOURCE_EXHAUSTED  | failure | failure |
      | FAILED_PRECONDITION | failure | failure |
      | ABORTED             | failure | failure |
      | OUT_OF_RANGE        | failure | success |
      | UNIMPLEMENTED       | failure | success |
      | INTERNAL            | failure | failure |
      | UNAVAILABLE         | failure | failure |
      | DATA_LOSS           | failure | failure |
      | UNAUTHENTICATED     | failure | success |
      | n/a                 | failure | failure |
    # last row with 'n/a' status represents the case where status is not available
