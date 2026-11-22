#!/usr/bin/env bash

# Installed by the phpBB plugin (plugins.sh --install phpbb); __WORKSPACE__ is the workspace it was installed into.
#
# The command-line tool (bin/phpbbcli.php) of one phpBB board of this workspace, in the project's web container: say
# what the board is, run a command of the tool, add or cancel the default accounts, add the sample content, take
# away what a stopped test run left. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="phpbb";

ARGPARSE_DESCRIPTION="Run the command-line tool of a phpBB board of __WORKSPACE__: status, a command, the default accounts, the sample content"
# The args file comes with the plugin: core/scripts/plugins/phpbb/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/phpbb/args/arg-phpbb-cli.sh || exit 1 ;

shift $#;

phpbb_cli_tool ;
