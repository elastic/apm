Feature: Agent Transport User agent Header

  Scenario: Default user-agent
    Given an agent
    When service name is not set
    When service version is not set
    Then the User-Agent header matches regex 'elasticapm-(java|ruby|python|dotnet|nodejs|go|php)/[^ ]*'

  Scenario: User-agent with service name only
    Given an agent
    When service name is set to 'myService'
    When service version is not set
    Then the User-Agent header matches regex 'elasticapm-(java|ruby|python|dotnet|nodejs|go|php)/[^ ]* myService'

  Scenario: User-agent with service name and service version
    Given an agent
    When service name is set to 'myService'
    When service version is set to 'v42'
    Then the User-Agent header matches regex 'elasticapm-(java|ruby|python|dotnet|nodejs|go|php)/[^ ]* myService/v42'
