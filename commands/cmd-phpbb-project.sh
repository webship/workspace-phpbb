#!/usr/bin/env bash

# workspace-name: phpBB (a forum)

# Installed by the phpBB plugin (plugins.sh --install phpbb); __WORKSPACE__ is the workspace it was installed into.
#
# Build a phpBB board in a container: the release package (its SHA-256 sum checked) unpacked in phpbb/, the docroot of
# a PHP project served by Apache. With --install it is installed with its own command-line installer on the
# project's database, the workspace account as its founder, and set up for testing; with --add-users it also gets
# the default accounts; with --sample-content the forums and topics the step pack is tested on.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="phpbb";
distribution_title="phpBB";
distribution_webroot="phpbb";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} board in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/phpbb/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/phpbb/args/arg-phpbb.sh || exit 1 ;

shift $#;

phpbb_build ;
