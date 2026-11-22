Feature: The session and the board index
  As a member of the board
  I want to log in and find the forums
  So that I can read and take part

  # Passes on a board built with --install --add-users --sample-content.

  Scenario: The login form says which of the two was wrong
    Given I am not logged in
    When I log in with the username "member" and the password "Not-the-password-2"
    Then the login should be refused with "You have specified an incorrect password."
    When I log in with the username "webship-test-nobody" and the password "Not-the-password-2"
    Then the login should be refused with "You have specified an incorrect username."
    And I should not be logged in

  Scenario: A member logs in and out
    Given I am not logged in
    When I log in as "member" with the login form
    Then I should be logged in as "member"
    When I log out
    Then I should not be logged in

  Scenario: A visitor sees the public forums, a moderator also the forum of the staff
    Given I am not logged in
    Then the board index should list the forum "General discussion" in the category "Community"
    And the board index should not list the forum "Staff room"
    And the forum "Archive" on the board index should be locked
    Given I am a logged in user with the "moderator" user
    When I go to the board index
    Then the board index should list the forum "Staff room" in the category "Staff"

  Scenario: A forum lists its announcement, its sticky topic and its topics
    Given I am not logged in
    When I open the forum "General discussion"
    Then the breadcrumbs should be "Board index", "Community" and "General discussion"
    And the forum should list the announcement "Board rules"
    And the topic "Start here: how this board works" in the forum should be sticky
    And the topic "Weekend baking thread" in the forum should have 12 replies
    When I open the topic "Weekend baking thread"
    Then the topic should have 13 posts
    And post 1 should be by "member"
    And post 1 should read "What is in your oven this weekend?"
