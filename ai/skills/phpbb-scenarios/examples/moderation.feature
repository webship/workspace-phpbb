Feature: Moderation
  As a moderator of the board
  I want to review what new members post and what members report
  So that the forums stay in order

  # Passes on a board built with --install --add-users --sample-content. The scenarios take away what they make.

  Scenario: The topic of a new member waits for approval, and a moderator approves it
    Given there is no topic "Webship test topic of a new member"
    And I am a logged in user with the "newmember" user
    When I start a new topic in "General discussion"
    And I write the subject "Webship test topic of a new member" in the editor
    And I write "Webship test: this post waits for approval." in the editor
    And I submit the post
    Then the board should say "it will need to be approved by a moderator"
    Given I am a logged in user with the "moderator" user
    Then the approval queue should list the topic "Webship test topic of a new member"
    When I approve the topic "Webship test topic of a new member"
    Then the board should say "The selected topic has been approved."
    And there is no topic "Webship test topic of a new member"

  Scenario: A member reports a post, and a moderator closes the report
    Given there is a topic "Webship test topic" in "General discussion" by "member"
    And "moderator" replied to the topic "Webship test topic" in "General discussion" with "Webship test reply of the moderator."
    And I am a logged in user with the "member" user
    When I open the topic "Webship test topic" in "General discussion"
    And I report the last post as "off topic" with "Webship test report."
    Given I am a logged in user with the "moderator" user
    Then the open reports should list "Re: Webship test topic"
    When I close the report of "Re: Webship test topic"
    Then the board should say "The selected report has been closed successfully."
    And there is no topic "Webship test topic"

  Scenario: A moderator locks a topic and moves it
    Given there is a topic "Webship test topic" in "General discussion" by "member"
    And I am a logged in user with the "moderator" user
    When I open the topic "Webship test topic" in "General discussion"
    And I lock the topic
    Then the topic should be locked
    When I unlock the topic
    And I move the topic to "Help and support"
    Then the breadcrumbs should be "Board index", "Community" and "Help and support"
    When I delete the topic permanently
    Then the forum should not list the topic "Webship test topic"
