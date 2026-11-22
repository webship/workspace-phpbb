Build a phpBB board (a forum) and its default accounts in a sites folder and prove it with its first webship-js feature.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Build the phpBB board named <name> (<with its first forum only|with the sample forums and topics>) with its default accounts in this sites folder and test it with webship-js
# ~/workspace/<dev|test|sandboxes|demos> · https://<name>.ddev.site · its mail at https://<name>.ddev.site:8026 · container-based (DDEV by default)
# the builder deletes a project of the same name first: stop if <name> is a site somebody still needs
# check free -g and df -h / first, build one site at a time
# nothing on the host: no PHP, Composer or tool of the board outside the containers; no hosted service, no account anywhere, no extension
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-phpbb-project.sh <name> --install --add-users <--sample-content|>
   (the release package checked and unpacked in the container, the board's own installer, the workspace account as its founder, the accounts)
2. bash cmd-tools-phpbb-cli.sh <name>
   tell me what the board is, its release, its addresses and the accounts it lists
3. bash cmd-tools-testing.sh <name>
   webship-js, the step pack, the users registry and tests/features/site.feature
4. bash cmd-tools-testing.sh <name> --dry-run --path tests/features/site.feature
5. bash cmd-tools-testing.sh <name> --run --path tests/features/site.feature

If a command fails, show the line that failed and stop. Do not retry with other flags.
When the feature is green: the address, the release, how many scenarios and steps passed.
Then ask me whether to keep the board or remove it with: bash cmd-tools-remove.sh <name>
"""
```
