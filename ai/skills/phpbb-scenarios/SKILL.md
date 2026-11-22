---
name: phpbb-scenarios
description: Write webship-js scenarios for a phpBB board (a forum) of the Webship Workspace from phrases that exist — the phpBB step pack's steps by area (the session and its refusals, the board index and its forums, a topic and its posts, the editor with its preview, attachments and drafts, private messages, search, the user control panel, moderation with its approval queue and reports, the administration control panel), the traps found on real boards, and three whole features. Use when asked to write, extend or fix scenarios for a board, or when a scenario of a forum fails on a phrase.
---

# phpbb-scenarios

Scenarios for a board built with the phpBB plugin (`bash cmd-phpbb-project.sh <site> --install --add-users`;
`--sample-content` for the forums and topics the pack is tested on) in a container-based workspace (DDEV by default),
tested with webship-js and `@webship-js/phpbb-steps` once `bash cmd-tools-testing.sh <site>` set the project up.
Every phrase below exists in the pack or in webship-js; a scenario names no platform.

## Accounts

- `Given I am a logged in user with the "member" user`: `administrator` (a founder: the administration control
  panel, and a moderator of every forum), `moderator` (a global moderator), `member` (a registered user),
  `newmember` (a newly registered user: its posts wait for approval). `Given I am not logged in` for a visitor.
- The accounts are made by the build (`cmd-tools-phpbb-cli.sh <site> --add-users`); a suite never creates or
  deletes one, and never writes a password: it logs in by the handle. The registration form is tested only through
  what it refuses.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I log in as "member" with the login form`, `I log in with the username "…" and the password "…"`, `the login should be refused with "…"`, `I am not logged in`, `I log out`, `I should be logged in`, `I should not be logged in`, `I should be logged in as "member"`, `I should be on the login page` (`… saying "…"`), `I should not be allowed to open "/mcp.php"`, `I ask for a password reset link for "member"`, `I set the password of "member" on the reset page` |
| Registration | `I open the registration form`, `I try to register with the username "…", the email "…" and the passwords "…" and "…"`, `the registration should be refused with "…"` |
| Board index | `I am on the board index`, `the board index should list the forum "…"` (`… in the category "…"`), `the board index should not list the forum "…"`, `the forum "…" on the board index should have 27 topics`, `the forum "…" on the board index should be locked`, `the forum "…" on the board index should list the subforum "…"`, `the board statistics should show "Our newest member" as "…"`, `the breadcrumbs should be "Board index", "Community" and "General discussion"` |
| A forum | `I open the forum "…"`, `I try to open the forum at "/viewforum.php?f=9"`, `I should be in the forum "…"`, `the forum should list the topic "…"` (`announcement`, `subforum`), `the forum should not list the topic "…"`, `the topic "…" in the forum should be sticky` (`an announcement`, `locked`, `moved`, `waiting for approval`, `reported`), `the topic "…" in the forum should have 12 replies`, `the topic "…" in the forum should be by "member"`, `the forum should have 27 topics`, `I go to page 2`, `I should be on page 2`, `I sort the topics by "Subject" in "Ascending" order`, `the first topic of the forum should be "…"` |
| A topic | `I open the topic "…" in "…"`, `I open the topic "…"`, `I should be reading the topic "…"`, `the topic should have 13 posts`, `post 1 should be by "member"`, `the last post should read "…"`, `the last post should quote "…" by "moderator"`, `the last post should show the attachment "…"`, `the topic should be locked` (`open`), `the topic should have the poll "…"`, `I vote for "Summer" in the poll`, `the poll should show 1 vote for "Summer"`, `the poll should show my vote for "Summer"`, `I bookmark the topic`, `I subscribe to the topic`, `I remove the bookmark of the topic`, `I unsubscribe from the topic`, `the topic should be bookmarked` |
| Posting | `I start a new topic in "…"`, `I start a reply to the topic`, `I quote the last post in a reply`, `I edit the last post`, `I write the subject "…" in the editor`, `I write "…" in the editor`, `I add "…" to the editor`, `the editor should have the subject "…"`, `the editor should contain "…"`, `I preview the post`, `the preview should show "…" in bold`, `I submit the post`, `I try to submit the post`, `the editor should show the error "…"`, `I attach the file "tests/fixtures/…" in the editor`, `I try to attach the file "…" in the editor`, `the attachment should be refused with "…"`, `the editor should list the attachment "…"`, `I reply to the topic with "…"`, `I quick reply with "…"`, `I should not see the quick reply`, `I should not be able to start a topic` (`reply`, `… because it is locked`), `I delete the last post permanently` |
| Private messages | `I go to my inbox` (`outbox`, `sent messages`), `my messages should list "…"`, `the message "…" should be unread`, `I open the message "…"`, `the message should be from "moderator"`, `the message should read "…"`, `I send the message "…" to "moderator" with "…"`, `I try to send the message "…" to "…" with "…"`, `I reply to the message with "…"`, `I delete the message "…"`, `I should have 1 unread message` |
| Search | `I search for "…"`, `I search the topics for "…" by "member" in "…"`, `the search should find 2 matches`, `the search results should show "…"`, `the search results should highlight "…"`, `I open the search result "…"`, `I open the quick link "Your posts"`, `the search page should be "Your posts"` |
| Control panels | `I go to the user control panel` (`moderator`, `administration`), `I open "Edit signature" under "Profile" in the user control panel`, `the control panel should show the page "…"`, `the control panel should offer the tab "…"`, `I set the setting "Location" to "…"`, `the setting "Location" should be "…"`, `I save the settings`, `I set my signature to "…"`, `my signature should be "…"`, `I save the post as a draft`, `my drafts should list "…"`, `I load the draft "…"`, `I delete the draft "…"`, `I go to the members list`, `the members list should list "member"`, `I open the profile of "member"`, `the profile should show "…"`, `I open the notifications menu`, `the notifications menu should list "…"` |
| Moderation | `I report the last post as "off topic" with "…"`, `the open reports should list "…"`, `I close the report of "…"`, `the approval queue should list the topic "…"`, `I approve the topic "…"`, `I disapprove the topic "…"`, `I lock the topic`, `I unlock the topic`, `I move the topic to "…"`, `I split the topic from post 2 into "…"`, `I delete the topic permanently`, `I should not see the moderator tools`, `the moderator log should show "Locked topic"`, `I should see the link to the moderator control panel` |
| Administration (read only) | `I open "Board settings" under "General" in the administration control panel`, `the setting "Disable board" should be "No"`, `the board statistic "Board version" should be "3.3"`, `the forum administration should list "…"`, `I open "Community" in the forum administration`, `I should not see the link to the administration control panel` |
| The board's answer | `the board should say "…"`: the notice page ("Information") of the step before |
| Mail | `an email with the subject "Account password reset" should be sent to "member"`, `the email with the subject "…" to "…" should contain "…"`, `I open the "reset_password" link of the email with the subject "…" to "member"`, `no email should be sent to "…"` |
| Test content | `there is no topic "…"`, `there is a topic "…" in "…" by "member"` (`… with:` and the text below), `"moderator" replied to the topic "…" in "…" with "…"`, `"member" has no message "…"`, `"moderator" sent the message "…" to "member" with "…"` |

Text, links, buttons, fields and status codes are webship-js's own: `I should see "…"`, `I press "…"`, `I go to "…"`,
`the response status code should be 404`.

## A scenario, start to end

A topic started with a preview, answered, and taken away again:

```gherkin
Feature: A topic
  Scenario: A member starts a topic and a moderator answers it
    Given there is no topic "Webship test topic"
    And I am a logged in user with the "member" user
    When I start a new topic in "Your first forum"
    And I write the subject "Webship test topic" in the editor
    And I write "Webship test: the first post of a topic." in the editor
    And I preview the post
    Then the preview should show "Webship test: the first post of a topic."
    When I submit the post
    Then I should be reading the topic "Webship test topic"
    Given I am a logged in user with the "moderator" user
    When I open the topic "Webship test topic" in "Your first forum"
    And I reply to the topic with "Webship test reply of the moderator."
    Then the topic should have 2 posts
    And the last post should be by "moderator"
    And there is no topic "Webship test topic"
```

## Traps found on real boards

- A form sent in the second it was made is refused ("The submitted form was invalid. Try submitting again."): the
  steps of the pack wait until the page is a second old; a scenario that fills a form with webship-js's own steps and
  presses its button at once can meet this.
- The board answers many actions with a notice page ("Information") that goes on by itself after three seconds:
  assert it with `the board should say "…"` right after the step, which keeps the notice of the step before.
- A waiting time between two posts (the flood interval) and a limit of failed logins stop a suite on a board that
  was not set up for testing: the builder's `--install` takes both away.
- The posts of `newmember` wait for approval: they show to their author and to the moderators only, and count for
  nobody else.
- A topic is found by its exact title, in the forum named; a moved topic is in its new forum.
- A locked forum still shows "New Topic" as a link, which answers "Forum locked": use
  `I should not be able to start a topic because it is locked`.
- A post deleted without "permanently" is deleted softly: the moderators still see it and count it.
- A message a person sent is in the outbox until its recipient reads it, then in the sent messages.
- The search leaves out words shorter than three letters and longer than fourteen, and what an account may not read.
- The administration control panel asks its administrator for the password once more, and its bare address leads
  back to the board index: enter it with `I go to the administration control panel`. A suite reads it, never
  writes it.
- A refusal the board answers with an error status (403, 404) makes the browser log a failed request: tag those
  scenarios `@js-off`.

## Examples

- [`examples/session-and-board.feature`](examples/session-and-board.feature): the login, the refusals, the board index, a forum and a topic.
- [`examples/posting.feature`](examples/posting.feature): a topic with a preview, a quote and a quick reply.
- [`examples/moderation.feature`](examples/moderation.feature): the approval queue, a report, a topic locked and moved.

Copy them into `tests/features/` of a project built with `--sample-content` and run them:

```bash
bash cmd-tools-testing.sh <site> --run --path tests/features/posting.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For a board.** Start with `ch10-authentication-authorization.md` (logins, refusals and what each role may open),
  `ch26-testing-cms-applications.md` (content made and removed, roles, a workflow across roles),
  `ch07-waiting-dynamic-content.md` (waiting on the site's own signals) and `ch06-form-testing-recipes.md` (forms
  and their errors).
