# code-freeze

A [Rein](https://github.com/tupe12334/rein) program. It answers whether a code freeze covers a repository and branch now. It reads only. It posts nothing.

## Install

```sh
rein install -g github:tupe12334/rein-code-freeze#v0.1.0
```

## Use

A caller awaits the program with the owner and repo, and the branch that a change would land on:

```text
/** Is a code freeze in force on this branch now? */
const freeze: Freeze = await @code-freeze/main(repo=owner/repo, branch=main);
```

- `repo`: the owner and repo, such as `owner/repo`.
- `branch`: the branch that a change would land on, such as `main`.

The answer is one line: `Return: frozen yes.` or `Return: frozen no.`, with the reason, the source link, and the end time when known.

## Flow

1. The repo's own signals are read first (`check_repo.rein`). A freeze counts when one is in force now for the branch:
   - a label named `freeze` or `code freeze` on an open issue or pull request;
   - an active ruleset named `freeze` or `code freeze` that targets the branch;
   - a `FREEZE` file at the root, or a freeze note in the README or CONTRIBUTING.
2. When the repo has no such signal, the Slack channels that announce releases or deploys are found at run time (`find_channels.rein`). No channel name is written in the program. A channel stays only when its topic or purpose says it announces releases, deploys or freezes.
3. With no such channel, the answer is `frozen no` and no message is read.
4. With a channel, the messages of the last 14 days are read (`read_freeze.rein`). The date comes from the clock. A message that says `code freeze` or `freeze`, and names the repo, its team or its release name, sets the state. A later `freeze lifted` message wins over an earlier freeze message. The thread of each message is read too.
5. The answer is built from the typed signal in `report.rein`.

A personal repository has no Slack signal, so it is not frozen unless its own signal is in force.

## Accepted risks

- The reading of a message or a signal is an agent answer. A wrong reading can hold a merge that should go on, or let one through. The reason and the source link name what was read, so a person can check it.
- The channel choice is an agent answer. A wrong channel gives a wrong reading, and the reason names the channel.
- The rules are prompt text. The walks check the text of each rule, not the answers.

## Develop

Run `git config core.hooksPath .githooks` once. Pushes then run `rein check .`, `scripts/walks.sh` and `shellcheck`. `scripts/walks.sh` walks the entry offline with fixed answers, for a frozen repo, a repo with no freeze, a freeze in Slack and a lifted freeze. It also checks the line length, the function length and the absence of `==`. `scripts/sabotage-lifted.sh` lets an earlier freeze win over a later lifted message in a copy, and checks that a walk fails. `scripts/sabotage-no-channel.sh` reads Slack with no channel in a copy, and checks that a walk fails.

## License

MIT
