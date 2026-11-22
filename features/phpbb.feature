Feature: The phpBB plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the phpBB builder, each AI folder lists the
  items of its kind the plugin ships, and the Plugins page lists the plugin with its steps.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "phpBB"
     When I go to "/settings/plugin/phpbb"
     Then I should see "@webship.co/workspace-phpbb"
      And I should see "cmd-phpbb-project.sh"
      And I should see "phpbb-site-builder"

  Scenario: A sites folder offers the phpBB builder
    Given I am on "/dev"
     Then "option[value='cmd-phpbb-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=phpbb-"
     Then I should see "phpbb-site-builder"
      And I should see "phpbb-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=phpbb-scenarios"
     Then I should see "phpbb-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=phpbb-test"
     Then I should see "phpbb-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=phpbb-"
     Then I should see "phpbb-build-and-test"
      And I should see "phpbb-scenarios-for-an-area"
