#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, and its name on the container runtime (on DDEV its host name too).')
parser.add_argument('--runtime',
                    dest='RUNTIME',
                    default="_none_",
                    choices=['ddev', 'docker', 'podman', 'kubernetes'],
                    help='The container runtime to build on: ddev (the default, or container.runtime of settings.yml), docker (Docker Compose), podman or kubernetes.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install the board with its own command-line installer, the workspace account as its founder, and set it up for testing.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator, moderator, member, newmember): the ones the test scenarios log in as.')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='With --install and --add-users, add the sample content the step pack is tested on: two categories, five forums, their topics, a poll and two private messages.')
parser.add_argument('-b', '--board-name',
                    default="",
                    help='The name of the board, shown at the top of its pages: the name of the project by default. Example: --board-name "Our board"')
parser.add_argument('-v', '--phpbb-version',
                    default="",
                    help='The release of the board, of the 3.3 line: 3.3.19 by default. Example: --phpbb-version 3.3.18')
parser.add_argument('-p', '--php-version',
                    default="",
                    help='The PHP of the web container: 8.3 by default (the release takes 7.2 to 8.3). Example: --php-version 8.1')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the board in a browser when it is ready.')
ARGEOF
