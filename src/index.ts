/**
 * phpBB for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the command-line tool in
 * the sites folders, their functions and argparse under core/scripts/plugins/phpbb/ (with phpbb-site.php, which the
 * builder runs with the board's PHP, and the first feature of a board), and its AI items (ai/ in this package) in the
 * folder of their kind: the agents in AI Agents, the skill in AI Skills, the command in AI Commands, the prompts in AI
 * Prompts. The dashboard needs nothing drawn for it: the builder is in the Build list because it is a
 * cmd-*-project.sh, the row menus are the core's, the AI items are listed like any other. What register() adds is
 * what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's own
 * files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/**
 * The plugin's name. A board is a PHP project of the container tool: the plugin claims it with
 * .ddev/config.phpbb.yaml, and the core's tools call its functions under phpbb.
 */
export const PLATFORM = 'phpbb';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-phpbb-project.sh', 'cmd-tools-phpbb-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['phpbb-site-builder', 'phpbb-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['phpbb-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['phpbb-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['phpbb-build-and-test', 'phpbb-scenarios-for-an-area'];

/** What the assistant is told about phpBB in this workspace. */
export function assistantContext(): string {
  return [
    'phpBB (a plugin, @webship.co/workspace-phpbb): a board is built with',
    '`bash cmd-phpbb-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos):',
    'the release package (3.3.19 by default, `--phpbb-version`), its sum checked, installed with the board\'s own command-line installer,',
    'with its default style, in a PHP project served by Apache in containers (DDEV by default), at https://<name>.ddev.site, its mail caught at https://<name>.ddev.site:8026;',
    '`--install` makes the workspace account its founder, `--add-users` adds the default accounts (administrator a founder, moderator a global moderator, member a registered user, newmember a newly registered user whose posts wait for approval), each @example.com;',
    '`--sample-content` adds the forums and topics the step pack is tested on.',
    '`bash cmd-tools-phpbb-cli.sh <name>` says what the board is and lists its accounts; `--run "<command>"` runs the board\'s command-line tool (bin/phpbbcli.php) in the container,',
    '`--sample-content` adds the sample content later, `--tidy` removes the test content a stopped run left, `--add-users` and `--cancel-users` manage the default accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the phpBB step pack; `--run` runs the suite.',
    `For phpBB work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run PHP, Composer or the board\'s tools on the host for a project; removing the project removes its database too.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
