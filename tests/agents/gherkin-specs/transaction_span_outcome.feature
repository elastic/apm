Feature: Transaction and span outcome.

  Scenario: Transaction outcome is set to 'success' for an instrumented server request with http status code < 500.
    Given an agent
    When the agent instruments requests to a server
    And a request is made to the server
    And the http status code in the server's response is 200
    Then the transaction outcome is 'success'

  Scenario: Transaction outcome is set to 'failure' for an instrumented server request with http status code 500.
    Given an agent
    When the agent instruments requests to a server
    And a request is made to the server
    And the http status code in the server's response is 500
    Then the transaction outcome is 'failure'

  Scenario: Transaction outcome is not set for an instrumented server request with no http status code.
    Given an agent
    When the agent instruments requests to a server
    And a request is made to the server
    And there is no http status code in the server's response
    Then the transaction outcome is not set

  Scenario: Span outcome is set to 'success' for an instrumented request to an external service with http status code 200, transaction outcome is set to 'success'.
    Given an agent
    When the agent instruments requests to a server
    When the agent instruments requests to an external service
    And a request is made to the server
    And a request is made to an external service
    And the http status code in the external service's response is 200
    And the http status code in the server's response is 200
    Then the span outcome is 'success'
    Then the transaction outcome is 'success'

  Scenario: Span outcome is set to 'failure' for an instrumented request to an external service with http status code 400, transaction outcome is set to 'success'.
    Given an agent
    When the agent instruments requests to a server
    When the agent instruments requests to an external service
    And a request is made to the server
    And a request is made to an external service
    And the http status code in the external service's response is 400
    And the http status code in the server's response is 200
    Then the span outcome is 'failure'
    Then the transaction outcome is 'success'

  Scenario: Span outcome is not set for an instrumented request to an external service with no http status code, transaction outcome is set to 'success'.
    Given an agent
    When the agent instruments requests to a server
    When the agent instruments requests to an external service
    And a request is made to the server
    And a request is made to an external service
    And there is no http status code in the external service's response
    And the http status code in the server's response is 200
    Then the span outcome is not set
    Then the transaction outcome is 'success'
