#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The board project in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A command of the board\'s command-line tool (bin/phpbbcli.php), with its arguments, run in the web container. Example: --run "cache:purge"')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its password, address, kind and groups back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts, with their posts (never the workspace account, the founder the installer made).')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='Add the sample content the step pack is tested on (and the default accounts, which write it). What is there already stays as it is.')
parser.add_argument('-t', '--tidy',
                    action='store_true',
                    default=False,
                    help='Remove what a test run that was stopped half way left behind: the topics and private messages titled "Webship test", open reports, and the drafts, bookmarks, votes and signatures of the default accounts.')
ARGEOF
