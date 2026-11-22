Feature: Posting
  As a member of the board
  I want to start a topic and answer it
  So that I take part in the discussion

  # Passes on a board built with --install --add-users --sample-content. The scenarios take away what they make.

  Scenario: A member starts a topic, with a preview first
    Given there is no topic "Webship test topic"
    And I am a logged in user with the "member" user
    When I start a new topic in "General discussion"
    And I write the subject "Webship test topic" in the editor
    And I write "Webship test: a [b]bold[/b] word." in the editor
    And I preview the post
    Then the preview should show "bold" in bold
    When I submit the post
    Then I should be reading the topic "Webship test topic"
    And post 1 should read "Webship test: a bold word."
    And there is no topic "Webship test topic"

  Scenario: A quote and a quick reply
    Given there is a topic "Webship test topic" in "General discussion" by "member"
    And "moderator" replied to the topic "Webship test topic" in "General discussion" with "Webship test reply of the moderator."
    And I am a logged in user with the "member" user
    When I open the topic "Webship test topic" in "General discussion"
    And I quote the last post in a reply
    And I add "Webship test: an answer to the quote." to the editor
    And I submit the post
    Then the last post should quote "Webship test reply of the moderator." by "moderator"
    When I quick reply with "Webship test quick reply."
    Then the topic should have 4 posts
    And the last post should read "Webship test quick reply."
    And there is no topic "Webship test topic"
