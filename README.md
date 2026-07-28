# roxen-agent-skills

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Roxen](https://img.shields.io/badge/roxen-6.3_%7C_8.3-informational.svg)](https://www.roxen.com/)
[![Verified](https://img.shields.io/badge/checks-62%2F62_against_real_source-brightgreen.svg)](verify.sh)
[![Agents](https://img.shields.io/badge/agents-Copilot_%7C_Codex_%7C_Claude-8957e5.svg)](#install)

Agent skills for working in a [Roxen WebServer](https://www.roxen.com/) codebase —
recognising and navigating modules, writing RXML tags, serving content, and tracing
requests.

Every fact here is checked against **real Roxen source**: `./verify.sh` fetches
`pikelang/Roxen` at a pinned commit and asserts each documented count, signature, and rule.

## Install

Plain markdown — no runtime, no build. The installer copies files where your agent looks.

```bash
git clone https://github.com/TheSmuks/roxen-agent-skills
cd your-roxen-project
../roxen-agent-skills/install.sh          # auto-detects what you use
```

| Command | Installs to | For |
|---------|-------------|-----|
| `install.sh claude` | `~/.claude/skills/` | Claude, all projects |
| `install.sh claude-project` | `./.claude/skills/` + `AGENTS.md` | Claude, this project |
| `install.sh copilot` | `./.github/skills/` + `./.github/instructions/` | GitHub Copilot |
| `install.sh codex` | `./.agents/skills/` + `AGENTS.md` | Codex |
| `install.sh agents` | `AGENTS.md` only | Cursor, Zed, Amp, anything AGENTS.md-aware |
| `install.sh /path/to/dir` | that directory | Anything else |

The Copilot instructions file applies automatically to `.pike`, `.rxml`, and anything under
`modules/`. Re-running is safe.

## Skill

| Skill | Covers |
|-------|--------|
| [`roxen-modules`](skills/roxen-modules/) | Module detection, the `module_type` bitfield, callbacks, `find_file` and response mappings, RXML tags, `RequestID`, `defvar`, logging and tracing |

## Three things that bite

**Tag classes must be named `Tag*`.** `query_tag_set()` discovers them with
`glob("Tag*", indices(this_object()))`, so a class named `GreetTag` is **silently
skipped** — no error, the tag simply never exists. It is the most common reason a newly
written RXML tag does nothing. Register non-conforming classes explicitly with
`RXML.TagSet(...)`.

**Modules use `inherit "module";`, not `inherit "module.pike";`.** The `.pike` spelling
appears in exactly **1 of 170** bundled module files. Detecting on it misses ~99% of real
modules — use `constant module_type` (134/170) as the primary signal.

**`module_type` is a bitfield.** `MODULE_LOCATION | MODULE_TAG` is legal and common. Match
on bits, not on a single constant.

## Verify

```bash
./verify.sh                          # fetches pinned pikelang/Roxen
ROXEN_SRC=/path/to/Roxen ./verify.sh # or check your own tree
```

```
passed: 62   failed: 0
```

Checks the module-signal counts, the full `MODULE_*` taxonomy, tag discovery in
`module.pike`, the `Roxen.pmod` response-helper signatures, the `CACHE()` and `QUERY()`
macros, and source encoding. Run it against your own Roxen tree to see where it differs
from upstream.

> Counts are pinned to the commit they were measured at
> (`6ed4566`). Override with `ROXEN_PIN` to re-measure against another revision.

## Does it actually help?

[`EVAL.md`](EVAL.md) is a 7-probe hand-run check of whether an agent's *behaviour* changes
with the skill installed. Each probe targets a misconception where the no-skill answer is
wrong — naming a tag class `GreetTag` instead of `TagGreet`, hand-editing config files,
searching for `inherit "module.pike"`. `verify.sh` proves the facts; `EVAL.md` probes the
behaviour.

## Related

- [pike-agent-skills](https://github.com/TheSmuks/pike-agent-skills) — the Pike language and
  toolchain skills these build on. Roxen modules are Pike programs, so both are useful
  together.

## License

MIT
