#!/usr/bin/env bash

# phpBB for the Webship Workspace: build a board from its release package, run its command-line tool, add its
# default accounts and its sample content, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install phpbb` in core/scripts/plugins/phpbb/functions/, where bootstrap sources it after
# the core's own functions. Everything runs in containers (DDEV by default), never on the host: the release package
# is fetched and checked in the web container, unpacked in phpbb/ (the docroot of a PHP project served by Apache,
# with the release's own rules) and installed with its own command-line installer on the project's database; the
# project's mail catcher takes its mail. The board itself, with its default style: no extension, no outside
# service, no account anywhere.
#
# Every container call is a plain verb of the container tool (config, start, exec, describe, launch), so the
# workspace's runtime layer can carry it to another runtime.
#
# The runtimes: a board is built on DDEV, or with --runtime on Docker Compose, Podman or Kubernetes. The commands
# are the same on each: `ddev <verb>` is DDEV itself on a DDEV project, and on another runtime the core's layer
# (fun-runtime.sh) gives the verb its meaning there. What differs is behind phpbb_runtime: the address (phpbb_url)
# and what the installer is told of it (plain HTTP on the site's port, the mail catcher on the host `mail`), the
# claim of the plugin on the project, and the mailbox the tests read (phpbb_mail_url).
#
# The container tool has no project type for a board, so a site of this plugin is recognised by the claim of the
# plugin on the project: on DDEV a file (.ddev/config.phpbb.yaml, written by the builder), on another runtime
# `platform: phpbb` in the x-webship block of compose.yaml (the core's rt_claim). Four names are the ones the
# core's tools look for:
#   set_phpbb_users          the default accounts                (cmd-tools-add-users.sh <project> phpbb)
#   add_phpbb_users          create them with the board's code   (the same tool, and --add-users of the builder)
#   cancel_phpbb_users       delete them                         (cmd-tools-cancel-users.sh <project> phpbb)
#   testing_configure_phpbb  the step pack in the testing stack  (cmd-tools-testing.sh <project>)

# The step pack a board is tested with, and the release line it is required at.
readonly PHPBB_STEPS_PACKAGE='@webship-js/phpbb-steps';
readonly PHPBB_STEPS_VERSION='^2.0.0';

# The release the builder installs when none is asked for, and the PHP of the web container (the release takes
# 7.2 up to 8.3).
readonly PHPBB_DEFAULT_VERSION='3.3.19';
readonly PHPBB_DEFAULT_PHP='8.3';

# Where the project and the board are in the web container.
readonly PHPBB_ROOT='/var/www/html';
readonly PHPBB_BOARD='/var/www/html/phpbb';

# The default accounts, the ones a scenario logs in as: an administrator (a founder), a global moderator, a
# registered user and a newly registered user, whose posts wait for approval. Accounts are configuration, created
# once on the board; a test suite never creates or deletes one. The founder the installer makes with --install is
# the workspace account and is not in this list.
function set_phpbb_users() {
  users=(administrator moderator member newmember);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_role='founder' ;
  user_moderator_role='moderator' ;
  user_member_role='member' ;
  user_newmember_role='newmember' ;
}

# The runtime of the project in this folder, or of a new build (--runtime, else the workspace's setting, else
# DDEV). A core without the runtime layer has DDEV only.
function phpbb_runtime() {
  if declare -f runtime_of > /dev/null ; then runtime_of ; else echo 'ddev' ; fi
}

# The address of the board in this folder: https://<name>.ddev.site on DDEV, http://127.0.0.1:<port> on Docker
# Compose and Podman, the node's address and a port on Kubernetes. Asked after `ddev config`.
function phpbb_url() {
  if declare -f rt_url > /dev/null ; then rt_url ; else echo "https://${PROJECT_NAME}.ddev.site" ; fi
}

# The address of the mailbox that catches the board's mail: port 8026 of a DDEV project; on another runtime the
# one the core's layer gives it (rt_mail_url), or nothing on a core whose layer gives it none yet.
function phpbb_mail_url() {
  if [ "$(phpbb_runtime)" == 'ddev' ] ; then echo "$(phpbb_url):8026" ;
  elif declare -f rt_mail_url > /dev/null ; then rt_mail_url ; fi
}

# Is this folder a board of this plugin? The claim of the plugin says so, which the core's rt_is_platform reads on
# every runtime: .ddev/config.phpbb.yaml on DDEV (the builder leaves it there), `platform: phpbb` in compose.yaml
# on another runtime.
function phpbb_is_project() {
  if declare -f rt_is_platform > /dev/null ; then rt_is_platform "$1" phpbb ; return $? ; fi
  [ -f "$1/.ddev/config.phpbb.yaml" ] ;
}

# Is the board of a folder installed? Its installer writes phpbb/config.php with PHPBB_INSTALLED, and the builder
# removes the folder of the installer after it.
function phpbb_is_installed() {
  grep -qs "PHPBB_INSTALLED" "${1:-.}/phpbb/config.php" && [ ! -d "${1:-.}/phpbb/install" ] ;
}

# Go to the project a tool was asked about, or say why not.
function phpbb_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! phpbb_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a board of this plugin (it has no .ddev/config.phpbb.yaml, and compose.yaml does not say platform: phpbb)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The default accounts (the list set_phpbb_users loads) as the site script takes them: base64 of a JSON object,
# {"accounts": [{"name", "email", "password", "role"}]}. The rows travel to Python in the environment, never on a
# command line.
function phpbb_payload() {
  local rows="" user name mail password role ;
  for user in "${users[@]}" ; do
    name="user_${user}_name"; mail="user_${user}_mail"; password="user_${user}_password"; role="user_${user}_role";
    # The workspace account is the founder the installer made: never one of the default accounts.
    [ "${!name}" == "${account_name}" ] && continue ;
    rows="${rows}${!name}|${!mail}|${!password}|${!role:-member}"$'\n' ;
  done
  PHPBB_ROWS="${rows}" python3 -c '
import base64, json, os
accounts = []
for row in os.environ["PHPBB_ROWS"].splitlines():
    if row.strip():
        name, email, password, role = row.split("|", 3)
        accounts.append({"name": name, "email": email, "password": password, "role": role})
print(base64.b64encode(json.dumps({"accounts": accounts}).encode()).decode())' ;
}

# Run verbs of phpbb-site.php with the board's PHP in the web container, in the board's folder, the payload on a
# first line before the script on PHP's standard input: no password on a command line, in a file of the project,
# or in what a failed run prints.
function phpbb_site() {
  local script="${WORKSPACE_SCRIPTS}/plugins/phpbb/phpbb-site.php" ;
  if [ ! -f "${script}" ] ; then
    echo "phpbb-site.php is not in ${WORKSPACE_SCRIPTS}/plugins/phpbb: install the plugin (plugins.sh --install phpbb)." ;
    return 1 ;
  fi
  { printf '<?php $SITE_PAYLOAD = "%s"; ?>' "$(phpbb_payload)"; cat "${script}"; } \
    | ddev exec -d "${PHPBB_BOARD}" "php -- $*" ;
}

# The board's own command-line tool (bin/phpbbcli.php), in the web container.
function phpbb_cli() {
  ddev exec -d "${PHPBB_BOARD}" "php bin/phpbbcli.php --no-ansi $*" < /dev/null ;
}

# Write the project's file for the board: the overlay of the container tool that says which release it holds. It
# is also the claim of the plugin on the project: the core's tools take the test users of a project of the "php"
# type from the plugin whose file it carries.
function phpbb_write_config() {
  local project_path="$1" version="$2" ;
  mkdir -p "${project_path}/.ddev" || return 1 ;
  cat > "${project_path}/.ddev/config.phpbb.yaml" <<YAMLEOF
# The board of this project: its release. Written by the phpBB builder of the workspace; build again rather than
# editing by hand.
web_environment:
  - PHPBB_VERSION=${version}
YAMLEOF
}

# The release the board runs, as its own code says it.
function phpbb_version() {
  sed -n "s/^@define('PHPBB_VERSION', '\(.*\)');/\1/p" "${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}/phpbb/includes/constants.php" 2>/dev/null | head -n 1 ;
}

# Is the project running? Asked of the container tool.
function phpbb_is_running() {
  ddev describe -j 2>/dev/null | grep -q '"status":"running"' ;
}

# Fetch the release package in the web container, check it against the sum its publisher gives beside it, and
# unpack it in phpbb/.
function phpbb_download() {
  local version="$1" line package ;
  line="$(printf '%s' "${version}" | cut -d. -f1,2)" ;
  package="https://download.phpbb.com/pub/release/${line}/${version}/phpBB-${version}.tar.bz2" ;
  ddev exec "set -e; cd /tmp && curl -sSfL --retry 3 -o phpbb.tar.bz2 '${package}' && curl -sSfL --retry 3 -o phpbb.sha256 '${package}.sha256' \
    && echo \"\$(cut -d' ' -f1 phpbb.sha256)  phpbb.tar.bz2\" | sha256sum -c - \
    && mkdir -p ${PHPBB_BOARD} && tar -xjf phpbb.tar.bz2 --strip-components=1 -C ${PHPBB_BOARD} && rm -f phpbb.tar.bz2 phpbb.sha256" < /dev/null ;
}

# Install the board with its own command-line installer ($1: the address of the board without its scheme, $2: its
# name): the workspace account as its founder, the project's database, the project's address, mail over SMTP to the mail catcher of the web container. The settings of the
# installer go to it on standard input and into its own folder, which is removed after the install, as the board
# asks.
function phpbb_install() {
  local host="$1" title="$2" ;
  # DDEV: HTTPS on the router's port, the mail catcher in the web container. Another runtime: plain HTTP on the
  # site's own port, the mail catcher on the host `mail` of the project's stack, and the board follows the
  # address it is asked on (a port of this machine, a node of the cluster, a tunnel).
  local protocol='https://' port='443' secure='true' forced='true' smtp_host='localhost' ;
  if [ "$(phpbb_runtime)" != 'ddev' ] ; then
    # The address without its scheme is a host and a port there.
    protocol='http://' ; port="${host##*:}" ; host="${host%:*}" ; secure='false' ; forced='false' ; smtp_host='mail' ;
  fi
  ddev exec "cat > ${PHPBB_BOARD}/install/install-config.yml" <<CONFIGEOF || return 1
installer:
    admin:
        name: ${account_name}
        password: ${account_pass}
        email: ${account_mail:-${account_name}@example.com}
    board:
        lang: en
        name: ${title}
        description: A board of the Webship Workspace
    database:
        dbms: mysqli
        dbhost: db
        dbport: 3306
        dbuser: db
        dbpasswd: db
        dbname: db
        table_prefix: phpbb_
    email:
        enabled: true
        smtp_delivery: true
        smtp_host: ${smtp_host}
        smtp_port: 1025
        smtp_auth: PLAIN
        smtp_user: ~
        smtp_pass: ~
    server:
        cookie_secure: ${secure}
        server_protocol: ${protocol}
        force_server_vars: ${forced}
        server_name: ${host}
        server_port: ${port}
        script_path: /
    extensions: []
CONFIGEOF
  ddev exec -d "${PHPBB_BOARD}" "php install/phpbbcli.php install install/install-config.yml --no-ansi --quiet" < /dev/null ;
  local status=$? ;
  ddev exec "rm -rf ${PHPBB_BOARD}/install" < /dev/null ;
  [ ${status} -eq 0 ] || return ${status} ;

  # The extension the release bundles and its installer turns on (a link service): off, and out of the database.
  if phpbb_cli extension:show | grep -q 'phpbb/viglink' ; then
    phpbb_cli extension:disable phpbb/viglink > /dev/null ;
    phpbb_cli extension:purge phpbb/viglink > /dev/null ;
  fi
}

# Build a board from nothing: the project and the release; with --install the installer, the workspace account as
# its founder and the settings a test run needs; with --add-users the default accounts; with --sample-content the
# test content of the step pack.
function phpbb_build() {
  trim_project_name ;
  local base_url mail_url runtime ;
  runtime="$(phpbb_runtime)" ;
  if [ "${RUNTIME:-_none_}" != '_none_' ] && [ "${RUNTIME}" != "${runtime}" ] ; then
    echo "--runtime ${RUNTIME} needs a Webship Workspace with the container runtimes (webship/workspace#694): update the workspace, or build on DDEV. Nothing was changed." ;
    exit 1 ;
  fi
  local version="${PHPBB_VERSION:-${site_phpbb_version:-${PHPBB_DEFAULT_VERSION}}}" ;
  local php_version="${PHP_VERSION:-${site_php_version:-${PHPBB_DEFAULT_PHP}}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;

  if ! [[ "${version}" =~ ^3\.3\.[0-9]+$ ]] ; then
    echo "--phpbb-version takes a release of the 3.3 line (3.3.19), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi
  if ! [[ "${php_version}" =~ ^(7\.[2-4]|8\.[0-3])$ ]] ; then
    echo "--php-version takes 7.2 to 8.3 (what the release accepts), not ${php_version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts go into the board --install makes." ;
    exit 1 ;
  fi
  if [ "${SAMPLE_CONTENT}" == 'yes' ] && [ "${ADD_USERS}" != 'yes' ] ; then
    echo "--sample-content needs --install and --add-users: the default accounts write the sample topics." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its container take it). Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${INSTALL}" == 'yes' ] && [ ${#account_pass} -lt 8 ] ; then
    echo "The workspace account's password is not set (core/config/settings.yml): --install makes it the board's founder. Nothing was changed." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its database.
  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  # A PHP project served by Apache (the release's own rules) from phpbb/, with the project's database and the
  # Node.js of the workspace for a test suite run in the web container.
  ddev config --project-type=php --docroot=phpbb --webserver-type=apache-fpm --php-version="${php_version}" \
    --project-name=${PROJECT_NAME} --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
  # The claim of the plugin on the project: its own file on DDEV, the core's rt_claim on another runtime.
  if [ "${runtime}" == 'ddev' ] ; then
    phpbb_write_config "${project_path}" "${version}" || exit 1 ;
  else
    rt_claim phpbb || exit 1 ;
  fi

  echo "Starting the project." ;
  ddev_up start -y < /dev/null || exit 1 ;
  # The address is the runtime's to say, once the project is configured: never a written ddev.site.
  base_url="$(phpbb_url)" ;
  mail_url="$(phpbb_mail_url)" ;
  echo "Fetching phpBB ${version} and checking its SHA-256 sum." ;
  phpbb_download "${version}" || { echo "The release package did not come, or its sum did not match." ; exit 1 ; } ;

  if [ "${INSTALL}" == 'yes' ] ; then
    echo "Installing it, with the workspace account ${account_name} as its founder." ;
    phpbb_install "${base_url#*://}" "${BOARD_NAME:-${PROJECT_NAME}}" || { echo "The installer did not finish." ; exit 1 ; } ;
    users=() ;
    phpbb_site settings || exit 1 ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_phpbb_users ;
      add_phpbb_users || exit 1 ;
      if [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
        cd "${project_path}" || exit 1 ;
        phpbb_site content || exit 1 ;
      fi
      users=() ;
    fi
    echo "${doc_name} ${PROJECT_NAME} has been installed: phpBB $(phpbb_version)." ;
    echo "The board: ${base_url}${mail_url:+ · its mail: ${mail_url}} · its founder: ${account_name}" ;
  else
    echo "${doc_name} ${PROJECT_NAME} is ready, not installed: phpBB $(phpbb_version) at ${base_url} shows its installer." ;
    echo "Build it again with --install (and --add-users) to install it with the workspace account as its founder." ;
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts with the board's own code: an account that is already there gets its password,
# address, kind and groups back. The list is loaded by the caller (set_phpbb_users): the core's add_users, the
# builder, the tool.
function add_phpbb_users() {
  phpbb_enter_project || return 1 ;
  if ! phpbb_is_installed . ; then
    echo "${doc_name}/${PROJECT_NAME} is not installed: build it with --install first." ;
    return 1 ;
  fi
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role:-member}";
    echo " ================================================================= ";
  done
  phpbb_site accounts ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts, with their posts (never the workspace account, the founder the installer made).
function cancel_phpbb_users() {
  phpbb_enter_project || return 1 ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  phpbb_site cancel ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-phpbb-cli.sh does: the first of --run, --add-users, --cancel-users, --sample-content, --tidy that
# was asked for; with none of them, what the board is.
function phpbb_cli_tool() {
  trim_project_name ;
  phpbb_enter_project || exit 1 ;

  if ! phpbb_is_running ; then
    ddev start -y < /dev/null || exit 1 ;
  fi

  if ! phpbb_is_installed . ; then
    echo "${doc_name}/${PROJECT_NAME}: phpBB $(phpbb_version), not installed (build it again with --install)." ;
    exit 0 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    phpbb_cli "${RUN}" ;
    exit $? ;
  fi

  set_phpbb_users ;
  local status=0 ;
  if [ "${ADD_USERS}" == 'yes' ] ; then
    add_phpbb_users ; status=$? ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    cancel_phpbb_users ; status=$? ;
  elif [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
    phpbb_site accounts content ; status=$? ;
  elif [ "${TIDY}" == 'yes' ] ; then
    phpbb_site tidy ; status=$? ;
  else
    echo "${doc_name}/${PROJECT_NAME}: phpBB $(phpbb_version)" ;
    echo "  the board: $(phpbb_url)" ;
    [ -n "$(phpbb_mail_url)" ] && echo "  its mail:  $(phpbb_mail_url)" ;
    echo "  its founder: ${account_name}" ;
    echo "" ;
    echo "Accounts:" ;
    phpbb_site list ; status=$? ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
  exit ${status} ;
}

# The step pack in the testing stack of a board. The core's testing_configure calls this in the project folder
# once webship-js is scaffolded and before the dependencies are installed; for a project that is not one of this
# plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, gives
# cucumber.js the tags that keep the pack's assertions that must fail out of a normal run, the mail catcher (the
# project's own, from inside the web container where the suite runs), the account that removes test content
# (moderator), the browser messages setting, and the users registry of the default accounts (a handle a scenario
# reads, mapped to an account; never the workspace account), and writes a first feature when the project has none
# of its own. Every part is skipped when it is already there, so a second run adds what the first missed and never
# resets a suite.
function testing_configure_phpbb() {
  local project_path="$1";
  phpbb_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  phpBB: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the phpBB step pack (${PHPBB_STEPS_PACKAGE} ${PHPBB_STEPS_VERSION}).";
  set_phpbb_users ;
  local registry="" user user_name user_mail user_password ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_name}|${!user_mail}|${!user_password}"$'\n' ;
  done

  # The builder names the project after its folder: its address follows.
  local site_name ;
  site_name="$(basename "${project_path}")" ;

  # On DDEV the board's address is written into cucumber.js, for a run that is given no LAUNCH_URL. On another
  # runtime no address is written: the Workspace's tests container hands the suite LAUNCH_URL and MAIL_URL.
  local address='' ;
  [ "$(cd "${project_path}" && phpbb_runtime)" == 'ddev' ] && address="$(cd "${project_path}" && PROJECT_NAME="${site_name:-${PROJECT_NAME}}" phpbb_url)" ;

  python3 - "${project_path}" "${PHPBB_STEPS_PACKAGE}" "${PHPBB_STEPS_VERSION}" 'PHPBB' "${registry}" "${address}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry, address = sys.argv[1:7]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
base = "(process.env.LAUNCH_URL || '%s').replace(/\\/+$/, '')" % address
if not re.search(r"^[ \t]*mailUrl:", src, re.M) and not address:
    additions += [
        pad + "// The project's mail catcher: the Workspace's tests container says where it is (MAIL_URL).",
        pad + "mailUrl: process.env.MAIL_URL || '',",
    ]
elif not re.search(r"^[ \t]*mailUrl:", src, re.M):
    additions += [
        pad + "// The project's mail catcher: in the web container (where the testing setup runs the suite) on its own port, else through the router.",
        pad + "mailUrl: process.env.MAIL_URL || (process.env.IS_DDEV_PROJECT ? 'http://127.0.0.1:8025' : `${%s}:8026`)," % base,
    ]
if not re.search(r"^[ \t]*moderator:", src, re.M):
    additions += [
        pad + "// The account that prepares and removes test content for the Given steps: a handle of `users` that moderates every forum.",
        pad + "moderator: process.env.MODERATOR || 'moderator',",
    ]
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// Browser messages: the board's own pages raise none. The scenarios of a refusal the board answers with an error",
        pad + "// status (403, 404) carry @js-off: the browser logs \"Failed to load resource\" for each of them.",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], ignore: 'net::ERR_NETWORK_CHANGED', beforeScenario: false, afterScenario: true },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of the board (the default accounts:",
        pad + "// cmd-tools-phpbb-cli.sh --add-users). Override one with %s_<HANDLE>_USERNAME and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, username, email, password in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', email: '%s', password: process.env.%s_PASSWORD || '%s' }," % (handle, env, username, email, env, password))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]
    print('  cucumber.js: the mail catcher, the moderating account and the browser messages setting')

# The address the suite opens when LAUNCH_URL is not set: the placeholder of the scaffold becomes the board's.
placeholder = "process.env.LAUNCH_URL || 'http://localhost:8080'"
if placeholder in src and address:
    src = src.replace(placeholder, "process.env.LAUNCH_URL || '%s'" % address)
    print('  cucumber.js: the address of the board (%s)' % address)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet.
  local feature="${WORKSPACE_SCRIPTS}/plugins/phpbb/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the board" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed board has them.
  if phpbb_is_installed "${project_path}" && ( cd "${project_path}" && add_phpbb_users > /dev/null 2>&1 ) ; then
    echo "  the default accounts are on the board (${users[*]})" ;
  elif phpbb_is_installed "${project_path}" ; then
    echo "  The default accounts could not be written: is the project running (start it from ${project_path})?" ;
  fi
}
