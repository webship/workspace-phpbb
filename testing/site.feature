Feature: The board answers, its login works and its accounts log in
  As the owner of the board
  I want the board index, the login and each default account to work, each in its role
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-phpbb-cli.sh --add-users); a scenario logs in by a handle of the
  # users registry in cucumber.js, so no password is written here. It passes on a board built with --install
  # --add-users, with or without --sample-content: it reads only what the installer and the accounts make.

  @critical
  Scenario: A visitor sees the first forum of the board
    Given I am not logged in
    Then the board index should list the forum "Your first forum" in the category "Your first category"
    And I should not be logged in

  Scenario Outline: The <account> account logs in through the login form
    Given I am not logged in
    When I log in as "<account>" with the login form
    Then I should be logged in as "<account>"

    Examples:
      | account       |
      | administrator |
      | moderator     |
      | member        |
      | newmember     |

  Scenario: A wrong password is refused
    Given I am not logged in
    When I log in with the username "member" and the password "Wrong-password-1"
    Then the login should be refused with "You have specified an incorrect password."

  Scenario: Each account gets the control panels of its work
    Given I am a logged in user with the "administrator" user
    Then I should see the link to the administration control panel
    And I should see the link to the moderator control panel
    Given I am a logged in user with the "moderator" user
    Then I should see the link to the moderator control panel
    And I should not see the link to the administration control panel
    Given I am a logged in user with the "member" user
    Then I should not see the link to the moderator control panel
    And I should not be allowed to open "/mcp.php"

  Scenario: The first topic of the board is there to read
    Given I am not logged in
    When I open the forum "Your first forum"
    Then the forum should have 1 topic
    And I should not be able to start a topic
