# @webship.co/workspace-phpbb

phpBB for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that makes a real
phpBB board (a forum) in containers, from its release package, installed with the board's own command-line
installer, with its default style, served by Apache, its mail sent to the project's mail catcher; a tool that runs
the board's command-line tool for the site; the default accounts; optional sample content; the
[phpBB step pack](https://github.com/webship/phpbb-steps) wired into the workspace's testing setup; and its AI items —
two agents, a skill, a command and two prompts — each listed in the workspace folder of its kind.

The workspace is container-based (DDEV by default): a board is a row like any other, so the row menus the core draws
(start, stop, launch, clone, remove, tests) work on it unchanged. The plugin claims its sites with a file of its own
(`.ddev/config.phpbb.yaml`), so the Tests menu of the row offers the plugin's test users (Workspace core 1.0.27 and
later; see [The default accounts](#the-default-accounts)).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`. Every call it makes to the
containers is a plain verb of the container tool (`config`, `start`, `exec`, `describe`, `launch`), the way the
workspace's own builders call it.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-phpbb --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate phpbb --with-needs                        # plugins.phpbb in settings.yml
bash core/scripts/plugins.sh --install phpbb                                      # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure phpbb                                    # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is idempotent.
`--uninstall` removes what it placed; an AI item you edited stays. `--remove phpbb` then takes the package out of
the dashboard.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-phpbb-project.sh`, `cmd-tools-phpbb-cli.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `phpbb-site-builder`, `phpbb-tester` | `ai-agents/` |
| The skill `phpbb-scenarios` | `ai-skills/` |
| The command `/phpbb-test` | `ai-commands/` |
| The prompts `phpbb-build-and-test`, `phpbb-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate phpbb --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install phpbb
```

Everything the builder runs for a site runs in containers, through the container tool the workspace already needs:
PHP, the database and the board are the containers'; the release package is fetched, checked and unpacked there
too. On the machine it uses Python 3 (which the workspace's own argument parsing already needs). The plugin asks for
no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-phpbb-project.sh` | The builder, in the Build list as **phpBB (a forum)**, installed into every sites folder |
| `commands/cmd-tools-phpbb-cli.sh` | The board's command-line tool for a site: what the board is and its accounts, a command of the tool, the sample content, the test content a stopped run left, the default accounts |
| `scripts/functions/fun-phpbb.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_phpbb_users`, `add_phpbb_users`, `cancel_phpbb_users`, `testing_configure_phpbb`) |
| `scripts/args/arg-phpbb.sh`, `arg-phpbb-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/phpbb-site.php` | The board's side of the build (the step pack's own script), run with the board's PHP and the board's own code in the web container: the settings a test run needs, the accounts, the sample content, the clean-up of test content |
| `testing/site.feature` | The first feature a board gets when testing is set up |
| `ai/agents/phpbb-site-builder.md` | The agent that builds and maintains boards with these commands |
| `ai/agents/phpbb-tester.md` | The agent that writes and runs scenarios with the phpBB step pack |
| `ai/skills/phpbb-scenarios/` | The skill: the step pack's phrases by area, the traps found on real boards, three example features |
| `ai/commands/phpbb-test.md` | The slash command `/phpbb-test <site>`: set up, match every step, run, report |
| `ai/prompts/phpbb-build-and-test.md`, `phpbb-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about phpBB here |
| `features/phpbb.feature` | Scenarios for the dashboard's own browser suite |
| `features/phpbb-runtimes.feature` | The row, the test users and the pages of a board built on Docker Compose and on Kubernetes |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from the reference

A board is a PHP application like the reference's, with no project type of its own in the container tool. The plugin
keeps the shape of the reference and changes only this:

| | WordPress (the reference) | phpBB |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=php --docroot=phpbb --webserver-type=apache-fpm`: Apache serves the board with the release's own rules |
| Recognised by | The project type | The file `.ddev/config.phpbb.yaml`: the release of the board in the environment of the web container, and the plugin's claim on the project |
| The runtime | PHP of the web image | PHP at `--php-version` (8.3 by default, the newest the release supports; it takes 7.2 to 8.3) |
| Getting the code | `wp core download` | The release package of the publisher, fetched in the web container and checked against the SHA-256 sum given beside it |
| Install | `wp core install` | The board's own command-line installer (`install/phpbbcli.php install`), with the workspace account as its founder; the folder of the installer is removed after it, as the board asks |
| Set up for testing | Nothing | No waiting time between posts, messages and searches, no limit of failed logins, no visual confirmation on the registration form, mail sent at once, the quick reply on: a test run posts and logs in from one address, far faster than a person |
| Extensions | None | None: the one the release bundles and its installer turns on (a link service of a company) is turned off and taken out of the database |
| Database | The container tool's MariaDB | The same |
| Mail | The container tool's mail catcher | The same: the board sends over SMTP to it (`https://<name>.ddev.site:8026`) |
| Accounts | WP-CLI | The board's own functions, through the plugin's script, the accounts on its standard input |
| The CLI | WP-CLI | The board's `bin/phpbbcli.php`, through `cmd-tools-phpbb-cli.sh --run` |
| Removing it | `ddev delete` | The same |
| Tests menu of the row | Reads the project type | The plugin's claim: core 1.0.27 and later offer the plugin's test users (`phpbb`) |

No public domain, no hosted service and no account anywhere: on DDEV the board answers at `https://<name>.ddev.site`
through the container tool's router; on Docker Compose and Kubernetes at the address the build prints (see
[Runtimes](#runtimes)).

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a board

```bash
cd ~/workspace/dev
bash cmd-phpbb-project.sh myboard --install --add-users                       # a board with the forum its installer makes
bash cmd-phpbb-project.sh myforum --install --add-users --sample-content      # with the sample forums and topics
bash cmd-phpbb-project.sh myold --install --add-users --php-version 8.1       # on an older PHP the release takes
```

| Flag | What it does |
| --- | --- |
| `--install` | Run the board's installer, with the workspace account as its founder, and set the board up for testing. Without it the board shows its installer |
| `--add-users` | With `--install`: add the default accounts |
| `--sample-content` | With `--install --add-users`: the content the step pack is tested on — the category "Community" with the forums "General discussion" (an announcement, a sticky topic, a topic of 13 posts, a poll, the subforum "Introductions"), "Help and support" (27 topics) and "Archive" (locked), the category "Staff" with "Staff room" (moderators and administrators only), and two private messages |
| `--board-name "<name>"` | The name of the board, shown at the top of its pages: the name of the project by default |
| `--phpbb-version <3.3.x>` | The release, of the 3.3 line: `3.3.19` by default |
| `--php-version <x.y>` | The PHP of the web container: `8.3` by default; the release takes `7.2` to `8.3` |
| `--runtime <name>` | The container runtime to build on: `ddev` (the default), `docker`, `kubernetes` or `podman`. See [Runtimes](#runtimes) |
| `--launch` | Open the board when it is ready |

On DDEV the board answers at `https://myboard.ddev.site` and its mail catcher at `https://myboard.ddev.site:8026`. A project
of the same name is deleted first. The board is in `phpbb/` of the project.

A build takes about a minute and a half. Check the free memory and disk first (`free -g`, `df -h /`), and build one
site at a time on a machine others use.

### Runtimes

```bash
bash cmd-phpbb-project.sh myboard --install --add-users                        # DDEV, the default
bash cmd-phpbb-project.sh myboard --install --add-users --runtime docker       # Docker Compose
bash cmd-phpbb-project.sh myboard --install --add-users --runtime kubernetes   # a Kubernetes cluster
```

Without `--runtime` a build takes `container.runtime` of the workspace's `settings.yml`, then DDEV.
It needs a Webship Workspace with the container runtimes
([webship/workspace#694](https://github.com/webship/workspace/issues/694)); on an older one the
builder refuses `--runtime` and builds on DDEV only.

RUNTIMES_TABLE

"Yes" means it was run on a real board of that runtime.

| Runtime | The board's address | What the project carries |
| --- | --- | --- |
| DDEV | `https://myboard.ddev.site`, its mail at `:8026` | `.ddev/config.yaml`, and `.ddev/config.phpbb.yaml`: the claim of the plugin |
| Docker Compose | `http://127.0.0.1:<port>`, printed by the build | `compose.yaml` (with `platform: phpbb`: the claim), `.webship/runtime/Dockerfile` |
| Kubernetes | `http://<node address>:<port>`, printed by the build | The same, and `k8s/` (the namespace `ws-myboard`) |

What differs on Docker Compose and Kubernetes:

- **The claim** is `platform: phpbb` in the `x-webship:` block of `compose.yaml` (the core's `rt_claim`), in place
  of `.ddev/config.phpbb.yaml`. The tools and the row's Tests menu read it.
- **The installer is told the runtime's address:** plain HTTP on the site's port, no secure cookie, and the board
  follows the address it is asked on. Its mail goes over SMTP to the host `mail` of the project's stack.
- **The database** needs nothing new: `db` / `db` / `db` on the host `db`, on every runtime.
- **The suite** runs in the Workspace's tests container, which hands it the board's address (`LAUNCH_URL`) and its
  mailbox (`MAIL_URL`); the testing setup writes no address into `cucumber.js` there.
- **Not there yet:** HTTPS and a host name are DDEV's. Podman runs the same code as Docker Compose and was not run
  yet.

The same commands work on every runtime: `cmd-tools-phpbb-cli.sh`, `cmd-tools-add-users.sh`,
`cmd-tools-testing.sh`. The pattern is the reference plugin's:
[On Docker Compose and Kubernetes](https://github.com/webship/workspace-wordpress/blob/1.0.x/docs/cms-plugin-pattern.md#on-docker-compose-and-kubernetes).

### Work on a board

```bash
bash cmd-tools-phpbb-cli.sh myboard                              # what the board is, its release, addresses and accounts
bash cmd-tools-phpbb-cli.sh myboard --run "cache:purge"          # a command of the board's tool, in the web container
bash cmd-tools-phpbb-cli.sh myboard --run "config:get sitename"
bash cmd-tools-phpbb-cli.sh myboard --run "list"                 # the commands the board's tool has
bash cmd-tools-phpbb-cli.sh myboard --sample-content             # the sample forums and topics, on a board without them
bash cmd-tools-phpbb-cli.sh myboard --tidy                       # remove the test content a stopped run left ("Webship test …")
bash cmd-tools-phpbb-cli.sh myboard --add-users                  # the default accounts
bash cmd-tools-phpbb-cli.sh myboard --cancel-users               # delete them again, with their posts
```

`--run` hands its words to `bin/phpbbcli.php` in the board's folder. A new release of the board is a new build
(`--phpbb-version`): the plugin does not update a board in place.

### The default accounts

| Account | Address | Role | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | a founder: the administration control panel, and a moderator of every forum | `administrator` |
| `moderator` | `moderator@example.com` | a global moderator: the moderator control panel, in every forum | `moderator` |
| `member` | `member@example.com` | a registered user | `member` |
| `newmember` | `newmember@example.com` | a newly registered user: its posts wait for a moderator's approval | `newmember` |

Each account has the password of the workspace's other default lists and logs in with its user name. They are made
by the plugin's script through the board's own functions, the accounts on PHP's standard input (never on a command
line or in a file); an account that is there already gets its password, its address, its kind and its groups back.
Cancelling deletes them with their posts. An account of your own, and the workspace account, stay when the default
accounts are added or cancelled. They are for local sites and for tests.

The row's Tests menu offers **Add the test users** and **Cancel the test users** for a board this plugin claims
(Workspace core 1.0.27 and later): they run the same list as

```bash
bash cmd-tools-add-users.sh myboard phpbb       # the core's tool, with the plugin's list
bash cmd-tools-cancel-users.sh myboard phpbb
```

### Test a board

```bash
bash cmd-tools-testing.sh myboard                  # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh myboard --run            # run the suite in the container
bash cmd-tools-testing.sh myboard --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a board it also adds `@webship-js/phpbb-steps` to `package.json`,
lists its step definitions in `cucumber.js` after webship-js's own, writes the mail catcher, the account that removes
test content (`moderator`), the users registry (the handles above, overridable with `PHPBB_<HANDLE>_USERNAME` and
`PHPBB_<HANDLE>_PASSWORD`), the tags that keep the pack's assertions that must fail out of a normal run, and the
board's address in place of the starter's `http://localhost:8080`. It places `tests/features/site.feature` when the
project has none, and makes sure the default accounts are on the board. Run it again and it adds what is missing and
keeps what you changed.

Until `@webship-js/phpbb-steps` is on npm, give the testing setup its tarball (`npm pack` of the pack) with
`bash cmd-tools-testing.sh myboard --add-steps <path to the tarball>`, then run the setup again.

A scenario of your own reads like this one, from the step pack's phrases (the skill `phpbb-scenarios` lists them by
area):

```gherkin
Feature: Moderation
  Scenario: The topic of a new member waits for approval, and a moderator approves it
    Given there is no topic "Webship test topic of a new member"
    And I am a logged in user with the "newmember" user
    When I start a new topic in "Your first forum"
    And I write the subject "Webship test topic of a new member" in the editor
    And I write "Webship test: this post waits for approval." in the editor
    And I submit the post
    Then the board should say "it will need to be approved by a moderator"
    Given I am a logged in user with the "moderator" user
    Then the approval queue should list the topic "Webship test topic of a new member"
    When I approve the topic "Webship test topic of a new member"
    Then the board should say "The selected topic has been approved."
    And there is no topic "Webship test topic of a new member"
```

`tests/features/site.feature` passes on a board built with `--install --add-users`, with or without the sample
content, and the features of the step pack pass on a board built with `--sample-content`. The pack's features have
names of their own (`board.feature`, `posting.feature`, …): copying them beside `site.feature` replaces nothing.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and `--install` places it
in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `phpbb-site-builder` | Build, maintain or remove a board with the commands above, in containers only |
| Agent | `phpbb-tester` | Set the testing stack up, look at the board in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `phpbb-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on real boards, and three features that pass on a board with the sample content and the default accounts |
| Command | `/phpbb-test <site> [feature or @tag]` | Run the suite of a board from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `phpbb-build-and-test` | Start a session that builds a board, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `phpbb-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of a board |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill or a command into
Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh phpbb-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh phpbb-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh phpbb-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the dashboard's **New
screen** form lists it as a template. By hand, fill the placeholders in and run the command of the file from the
folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and the file layout are
Claude Code's, the body of each item is plain Markdown that names no tool or feature of one CLI, a command says in
words what its arguments are, and the text between the triple quotes of a prompt can be given to another AI CLI as it
is.

Every step phrase the items show is checked against the definitions of the step pack and of webship-js
(`tests/fixtures/step-definitions.txt`), and every command and flag against the plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's `features/phpbb.feature`
against a dashboard with this plugin installed (`webship/workspace/.github/workflows/plugin-browser-suite.yml`).

The phpBB name is a trademark of its owner; this plugin is not affiliated with or endorsed by them.
