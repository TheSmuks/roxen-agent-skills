# Installing these skills (instructions for an agent)

You are an AI coding agent and someone asked you to install these skills. Work out which
method fits the host you are running in, run it, then verify. Do not guess — the detection
commands below are cheap.

## 1. Detect what you have

```sh
command -v copilot && copilot skill --help >/dev/null 2>&1 && echo "copilot-cli"
gh skill --help >/dev/null 2>&1 && echo "gh-skill"
[ -d "$HOME/.claude" ]   && echo "claude"
[ -d "$HOME/.copilot" ]  && echo "copilot-dirs"
[ -d "$HOME/.agents" ]   && echo "agents-dirs"
ls .github/skills .claude/skills .agents/skills 2>/dev/null
```

## 2. Pick a method

Take the first that applies.

| If | Use | Why |
|----|-----|-----|
| `copilot skill` exists | `copilot skill add <repo>/skills` | registers the directory, so bundled tools stay reachable |
| `gh skill` exists | `gh skill install TheSmuks/roxen-agent-skills` | copies the whole skill folder, tools included |
| neither | `<repo>/install.sh <target>` | plain copy; targets listed in `--help` |

`install.sh` targets: `claude`, `claude-project`, `copilot`, `copilot-user`, `codex`,
`agents`, `agents-user`, or a directory path. `install.sh` with no argument auto-detects.

### A note on URL installs

`copilot skill add <url>` materialises **only `SKILL.md`**. This repo's skill has no
bundled tools, so a URL install is not lossy here — but `lab/` is a development harness
that no install method copies. Clone the repo to use it.

## 3. Verify — do not skip this

Installing is not the same as being discovered. Check that the host actually sees them:

```sh
copilot skill list | grep pike-      # Copilot CLI
claude -p "list your pike-* skills"  # Claude Code
```

You should see `roxen-modules`.

## 4. Report honestly

State which method you used, which skills the host now lists, and whether the tools came
with them. If discovery returned nothing, say the install did not take effect rather than
assuming it will work later.

## Related

Roxen modules are Pike programs, so `TheSmuks/pike-agent-skills` applies alongside this
one — install both for a Roxen codebase.
