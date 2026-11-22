import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-phpbb.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A board of this plugin has the builder's .ddev/config.phpbb.yaml and an installed board (phpbb/config.php, no
 * install/ folder).
 */
function project(kind: 'phpbb' | 'drupal') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'phpbb-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  if (kind === 'phpbb') {
    fs.writeFileSync(path.join(dir, '.ddev', 'config.phpbb.yaml'), 'web_environment:\n  - PHPBB_VERSION=3.3.19\n');
    fs.mkdirSync(path.join(dir, 'phpbb', 'includes'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'phpbb', 'config.php'), "<?php\n@define('PHPBB_INSTALLED', true);\n");
    fs.writeFileSync(path.join(dir, 'phpbb', 'includes', 'constants.php'), "<?php\n@define('PHPBB_VERSION', '3.3.19');\n");
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'phpbb'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'phpbb', 'site.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'phpbb-site.php'), path.join(scripts, 'plugins', 'phpbb', 'phpbb-site.php'));
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its calls (and of what it reads on
 * stdin: its first 400 characters); asked whether the project runs, the recorder says it does.
 */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; case "$*" in "describe -j"*) echo \'{"raw":{"status":"running"}}\' ;; esac ; if [ ! -t 0 ] ; then head -c 1500 | tr "\\n" " " | sed "s/^/  stdin: /" >> "${DDEV_LOG:-/dev/null}" ; echo >> "${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

/**
 * The accounts a recorded call of phpbb-site.php carried: the base64 of their JSON object, in a first line before the
 * script on its standard input, never on its command line.
 */
function payloadOf(log: string, call: string) {
  assert.doesNotMatch(call, /SITE_PAYLOAD|password|dD\./i, 'no account on the command line');
  const lines = log.split('\n');
  const stdin = lines[lines.indexOf(call) + 1] || '';
  const m = stdin.match(/^  stdin: <\?php \$SITE_PAYLOAD = "([A-Za-z0-9+\/=]+)"; \?><\?php /);
  assert.ok(m, `the accounts come first on stdin, then the script: ${stdin.slice(0, 120)}`);
  return JSON.parse(Buffer.from(m![1], 'base64').toString('utf8'));
}

const ENV = (p: { root: string; scripts: string }, log: string) => ({ WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'Owner-pass-1' });

test('the default accounts are a founder, a global moderator, a member and a new member, with example addresses', () => {
  const r = bash('set_phpbb_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!g}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'moderator', 'member', 'newmember']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['founder', 'moderator', 'member', 'newmember']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 10, 'long enough for the password rules of a board');
  }
});

test('the accounts are written by the site script with the board\'s PHP, in the board\'s folder, never in a file or on a command line', () => {
  const p = project('phpbb');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_phpbb_users ; add_phpbb_users', ENV(p, log));
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const call = written.split('\n').find((l) => l.startsWith('ddev exec -d /var/www/html/phpbb')) as string;
  assert.strictEqual(call, 'ddev exec -d /var/www/html/phpbb php -- accounts');
  const payload = payloadOf(written, call);
  assert.deepStrictEqual(payload.accounts.map((a: any) => [a.name, a.email, a.role]), [
    ['administrator', 'administrator@example.com', 'founder'], ['moderator', 'moderator@example.com', 'moderator'],
    ['member', 'member@example.com', 'member'], ['newmember', 'newmember@example.com', 'newmember'],
  ]);
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => !['.ddev', 'phpbb', 'cucumber.js', 'package.json'].includes(f)), [], 'no file with a password is left in the project');
});

test('the workspace account is never one of the default accounts: a list that names it leaves it out', () => {
  const p = project('phpbb');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_phpbb_users ; cancel_phpbb_users', { ...ENV(p, log), account_name: 'administrator' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const call = written.split('\n').find((l) => l.endsWith('php -- cancel')) as string;
  assert.ok(call, 'the cancel verb is called');
  assert.deepStrictEqual(payloadOf(written, call).accounts.map((a: any) => a.name), ['moderator', 'member', 'newmember']);
});

test('cancelling the accounts deletes the default ones through the site script', () => {
  const p = project('phpbb');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_phpbb_users ; cancel_phpbb_users', ENV(p, log));
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const call = written.split('\n').find((l) => l.endsWith('php -- cancel')) as string;
  assert.deepStrictEqual(payloadOf(written, call).accounts.map((a: any) => a.name), ['administrator', 'moderator', 'member', 'newmember']);
});

test('the builder refuses what it cannot build before it changes anything', () => {
  const p = project('drupal');
  const log = path.join(p.root, 'ddev.log');
  const run = (vars: string) => bash(`trim_project_name() { :; } ; drop_database() { echo DROPPED ; } ; ${vars} ; phpbb_build`, ENV(p, log));
  const cases: [string, RegExp][] = [
    ['PROJECT_NAME=board1 ; PHPBB_VERSION=4.0.0 ; INSTALL=yes', /--phpbb-version takes a release of the 3\.3 line/],
    ['PROJECT_NAME=board1 ; PHP_VERSION=8.4 ; INSTALL=yes', /--php-version takes 7\.2 to 8\.3/],
    ['PROJECT_NAME=board1 ; ADD_USERS=yes', /--add-users needs --install/],
    ['PROJECT_NAME=board1 ; INSTALL=yes ; SAMPLE_CONTENT=yes', /--sample-content needs --install and --add-users/],
    ['PROJECT_NAME=Board_1 ; INSTALL=yes', /must be small letters, digits and dashes/],
    ['PROJECT_NAME=board1 ; INSTALL=yes ; account_pass=short', /The workspace account's password is not set/],
  ];
  for (const [vars, message] of cases) {
    const r = run(vars);
    assert.strictEqual(r.status, 1, `${vars}: ${r.stdout}`);
    assert.match(r.stdout, message);
    assert.doesNotMatch(r.stdout, /DROPPED/, `${vars}: nothing was removed`);
  }
  assert.ok(!fs.existsSync(log), 'the container tool was never called');
});

test('the builder writes the claim of the plugin: the release of the board in the web container\'s environment', () => {
  const p = project('drupal');
  const r = bash(`phpbb_write_config ${p.dir} 3.3.19`);
  assert.strictEqual(r.status, 0, r.stderr);
  const config = fs.readFileSync(path.join(p.dir, '.ddev', 'config.phpbb.yaml'), 'utf8');
  assert.match(config, /^web_environment:\n  - PHPBB_VERSION=3\.3\.19$/m);
  assert.strictEqual(bash(`phpbb_is_project ${p.dir} && echo yes`).stdout.trim(), 'yes', 'the project is now one of the plugin\'s');
});

test('a board is installed once its installer wrote its settings and its folder is gone', () => {
  const p = project('phpbb');
  assert.strictEqual(bash(`phpbb_is_installed ${p.dir} && echo yes || echo no`).stdout.trim(), 'yes');
  fs.mkdirSync(path.join(p.dir, 'phpbb', 'install'));
  assert.strictEqual(bash(`phpbb_is_installed ${p.dir} && echo yes || echo no`).stdout.trim(), 'no', 'the folder of the installer is still there');
  const r = bash('phpbb_version', { WORKSPACE_ROOT: p.root, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.stdout.trim(), '3.3.19', 'the release is read from the board\'s own code');
});

test('the testing hook adds the step pack, the users registry, the mail catcher, the moderating account, the tags and a first feature, once', () => {
  const p = project('phpbb');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_phpbb ${p.dir}`, ENV(p, log));
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/phpbb-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/phpbb-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /administrator: \{ username: process\.env\.PHPBB_ADMINISTRATOR_USERNAME \|\| 'administrator', email: 'administrator@example\.com', password: process\.env\.PHPBB_ADMINISTRATOR_PASSWORD \|\| '[^']+' \},/);
  assert.match(cucumber, /newmember: \{ username: process\.env\.PHPBB_NEWMEMBER_USERNAME \|\| 'newmember'/);
  assert.match(cucumber, /moderator: process\.env\.MODERATOR \|\| 'moderator',/);
  assert.match(cucumber, /mailUrl: process\.env\.MAIL_URL \|\| \(process\.env\.IS_DDEV_PROJECT \? 'http:\/\/127\.0\.0\.1:8025' : `\$\{\(process\.env\.LAUNCH_URL \|\| 'https:\/\/site1\.ddev\.site'\)\.replace\(\/\\\/\+\$\/, ''\)\}:8026`\),/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  assert.match(cucumber, /launchUrl: process\.env\.LAUNCH_URL \|\| 'https:\/\/site1\.ddev\.site'/, 'the board\'s address, from the name of its folder, in place of the scaffold\'s');
  assert.doesNotMatch(cucumber, /owner1|Owner-pass-1/, 'the workspace account is no test user');
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, c.worldParameters.users.member.username, c.worldParameters.javascript.mode, c.worldParameters.moderator, c.worldParameters.mailUrl]))`], { encoding: 'utf8', env: { ...process.env, IS_DDEV_PROJECT: '', LAUNCH_URL: '' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, username, mode, moderator, mailUrl] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['administrator', 'moderator', 'member', 'newmember']);
  assert.match(tags, /not @must-fail/);
  assert.strictEqual(username, 'member');
  assert.strictEqual(mode, 'warn');
  assert.strictEqual(moderator, 'moderator');
  assert.strictEqual(mailUrl, 'https://site1.ddev.site:8026');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /php -- accounts$/m, 'the board gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the first feature of the plugin and the features of the step pack never share a name', () => {
  // The testing setup places tests/features/site.feature; the pack's own features are copied beside it.
  const placed = 'site.feature';
  assert.match(fs.readFileSync(FUNCTIONS, 'utf8'), /tests\/features\/site\.feature/);
  for (const f of fs.readdirSync(path.join(PKG, 'ai', 'skills', 'phpbb-scenarios', 'examples'))) assert.notStrictEqual(f, placed, `the example ${f} would replace the first feature`);
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`cd ${p.dir} && testing_configure_phpbb ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the command-line tool refuses a project that is not a board of the plugin', () => {
  const p = project('drupal');
  const r = bash('PROJECT_NAME=site1 ; RUN="cache:purge" ; trim_project_name() { :; } ; phpbb_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a board of this plugin/);
});

test('the command-line tool runs a command of the board\'s own tool in the web container, and tidies through the site script', () => {
  const p = project('phpbb');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('RUN="config:get sitename" ; trim_project_name() { :; } ; phpbb_cli_tool', ENV(p, log));
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(fs.readFileSync(log, 'utf8'), /^ddev exec -d \/var\/www\/html\/phpbb php bin\/phpbbcli\.php --no-ansi config:get sitename$/m);
  fs.rmSync(log);
  const t = bash('RUN=_none_ ; TIDY=yes ; trim_project_name() { :; } ; phpbb_cli_tool', ENV(p, log));
  assert.strictEqual(t.status, 0, t.stderr + t.stdout);
  assert.match(fs.readFileSync(log, 'utf8'), /^ddev exec -d \/var\/www\/html\/phpbb php -- tidy$/m);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /phpbb|prosilver/i, s);
  assert.doesNotMatch(feature, /dD\.123123ddd"/);
  assert.doesNotMatch(feature, /register with/i, 'a suite never creates an account');
});
