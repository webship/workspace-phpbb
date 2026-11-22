import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
  // The machine files land side by side in core/scripts/plugins/phpbb/: no two may share a name.
  const names = manifest.scripts.machine.map((f: string) => path.basename(f));
  assert.strictEqual(new Set(names).size, names.length, 'the machine files have names of their own');
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/phpbb\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    assert.match(src, /^distribution_name="phpbb";$/m, `${f}: the user list of the core's tools is phpbb`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-phpbb.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-phpbb-project.sh'), /^# workspace-name: phpBB \(a forum\)$/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-phpbb-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the site script is PHP the board can run, with every verb the functions call, and is the step pack\'s own', () => {
  const src = read('scripts/phpbb-site.php');
  for (const verb of ['settings', 'accounts', 'cancel', 'list', 'content', 'tidy', 'version']) assert.match(src, new RegExp(`case '${verb}':`), `phpbb-site.php has the verb ${verb}`);
  assert.match(src, /^<\?php\n/, 'a PHP script, read on standard input after its payload');
  assert.match(src, /php_sapi_name\(\) !== 'cli'/, 'it runs on the command line only');
  assert.match(src, /require\(\$phpbb_root_path \. 'common\.' \. \$phpEx\);/, 'it works with the board\'s own code');
  for (const fn of ['user_add(', 'group_user_add(', 'submit_post(', 'submit_pm(', 'update_forum_data(', 'copy_forum_permissions(']) assert.ok(src.includes(fn), `it uses the board's ${fn}…)`);
  for (const setting of ['flood_interval', 'max_login_attempts', 'ip_login_limit_max', 'enable_confirm', 'email_package_size', 'new_member_post_limit', 'allow_quick_reply']) {
    assert.match(src, new RegExp(`'${setting}'\\s+=> `), `the settings of a test run: ${setting}`);
  }
  assert.doesNotMatch(src, /dD\.123123ddd/, 'no password in the script: the accounts come in its payload');
  const fns = read('scripts/functions/fun-phpbb.sh');
  for (const verb of [...fns.matchAll(/phpbb_site ([a-z ]+?) ?[;|]/g)].flatMap((m) => m[1].trim().split(/\s+/))) {
    assert.match(src, new RegExp(`case '${verb}':`), `the functions call the verb ${verb}, which the script has`);
  }
});

test('the claim file is the plugin\'s own name, and is a real overlay of the container tool: the release of the board', () => {
  const src = read('scripts/functions/fun-phpbb.sh');
  assert.match(src, /\.ddev\/config\.phpbb\.yaml/, 'the file the core reads as the plugin\'s claim (#490): config.<plugin>.yaml');
  const yaml = (src.match(/config\.phpbb\.yaml" <<YAMLEOF\n([\s\S]*?)\nYAMLEOF/) || [])[1] || '';
  assert.match(yaml, /^web_environment:\n  - PHPBB_VERSION=\$\{version\}$/m, 'the release the project holds, in the environment of its web container');
  assert.match(src, /^function set_phpbb_users\(\) \{/m, 'the claim names a plugin with a user list: set_<plugin>_users');
});

test('the functions carry the names the core\'s tools look for, and build the board the official way', () => {
  const src = read('scripts/functions/fun-phpbb.sh');
  for (const fn of ['set_phpbb_users', 'add_phpbb_users', 'cancel_phpbb_users', 'testing_configure_phpbb', 'phpbb_build', 'phpbb_cli_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.doesNotMatch(src, /^function build_phpbb\(\)/m, 'the core\'s own example function is not redefined');
  assert.match(src, /--project-type=php --docroot=phpbb --webserver-type=apache-fpm/, 'a PHP project served by Apache: the container tool has no type for a board');
  assert.match(src, /download\.phpbb\.com\/pub\/release\/\$\{line\}\/\$\{version\}\/phpBB-\$\{version\}\.tar\.bz2/, 'the release package of the publisher');
  assert.match(src, /sha256sum -c -/, 'checked against the sum the publisher gives');
  assert.match(src, /php install\/phpbbcli\.php install install\/install-config\.yml/, 'the board\'s own command-line installer');
  assert.match(src, /rm -rf \$\{PHPBB_BOARD\}\/install/, 'the folder of the installer goes after the install, as the board asks');
  assert.match(src, /extension:disable phpbb\/viglink/, 'the bundled extension is turned off: the board itself, with no outside service');
  assert.match(src, /name: \$\{account_name\}\n\s+password: \$\{account_pass\}/, 'the workspace account is the founder the installer makes');
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the build runs the Node.js of the workspace rule');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('every container call is a plain verb of the container tool, and no file of the tool is read where a verb exists', () => {
  const src = read('scripts/functions/fun-phpbb.sh');
  const code = src.split('\n').filter((l) => !/^\s*#/.test(l)).join('\n');
  const verbs = new Set([...code.matchAll(/(?<![\w."'-])ddev ([a-z-]+)/g)].map((m) => m[1]));
  for (const verb of verbs) assert.ok(['config', 'exec', 'start', 'describe', 'launch'].includes(verb), `ddev ${verb} is a plain verb the runtime layer carries`);
  assert.doesNotMatch(code, /docker (exec|run|compose|inspect|ps)/, 'no call past the container tool');
  assert.doesNotMatch(code, /supervisorctl/, 'no daemon of the web image is driven');
  assert.doesNotMatch(code, /\.ddev\/config\.yaml/, 'the project\'s own file of the container tool is not read: the project is named after its folder');
  // The one file of the tool the plugin writes is its claim, which the core asks for by that name.
  const files = new Set([...code.matchAll(/\.ddev\/([A-Za-z0-9._-]+)/g)].map((m) => m[1]));
  assert.deepStrictEqual([...files], ['config.phpbb.yaml']);
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-phpbb-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/phpbb-tester.md');
  assert.match(tester, /Never create or delete an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'phpbb', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-phpbb.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
});

test('the builder starts no server of its own: the web container serves the board, and nothing is restarted', () => {
  const src = read('scripts/functions/fun-phpbb.sh');
  assert.doesNotMatch(src, /web_extra_daemons|restart/, 'no daemon to start, so none to restart while it starts');
  assert.match(src, /ddev_up start -y < \/dev\/null/, 'the project is started once, with its standard input closed');
  for (const line of src.split('\n').filter((l) => /^\s*ddev exec /.test(l) && !/\\$/.test(l) && !/<<|\|/.test(l))) {
    assert.match(line, /< \/dev\/null/, `a container call closes its standard input: ${line.trim().slice(0, 80)}`);
  }
});
