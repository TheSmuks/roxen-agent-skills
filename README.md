# roxen-agent-skills

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Roxen](https://img.shields.io/badge/roxen-6.3_%7C_8.3-informational.svg)](https://www.roxen.com/)
[![Verified](https://img.shields.io/badge/checks-73%2F73_against_real_source-brightgreen.svg)](verify.sh)
[![Agents](https://img.shields.io/badge/agents-Copilot_%7C_Codex_%7C_Claude-8957e5.svg)](#install)

Agent skills for working in a [Roxen WebServer](https://www.roxen.com/) codebase —
recognising and navigating modules, writing RXML tags, serving content, and tracing
requests.

Every fact here is checked against **real Roxen source**: `./verify.sh` fetches
`pikelang/Roxen` at a pinned commit and asserts each documented count, signature, and rule.

## Install

**Working with an agent?** Point it at [`INSTALL.md`](INSTALL.md) — *"read INSTALL.md and
install these skills"*. It detects the host, picks a method, and verifies discovery.

Doing it yourself:

```bash
./install.sh claude        # or: codex, copilot, agents-user, ...
```

If your `gh` has the `skill` command, that is GitHub's own installer and handles target
directories, pinning and provenance:

```bash
gh skill install TheSmuks/roxen-agent-skills --pin v1.1.0
```

> `gh skill` is newer than gh 2.46.0, which does not have it. Check with
> `gh skill --help` first.

### install.sh

```bash
git clone https://github.com/TheSmuks/roxen-agent-skills
cd your-roxen-project
../roxen-agent-skills/install.sh          # auto-detects what you use
```

| Command | Installs to | For |
|---------|-------------|-----|
| `install.sh copilot` | `./.github/skills/` + `./.github/instructions/` | GitHub Copilot, this project |
| `install.sh copilot-user` | `~/.copilot/skills/` | Copilot, all projects |
| `install.sh claude` | `~/.claude/skills/` | Claude, all projects |
| `install.sh claude-project` | `./.claude/skills/` + `AGENTS.md` | Claude, this project |
| `install.sh codex` | `./.agents/skills/` + `AGENTS.md` | Codex |
| `install.sh agents-user` | `~/.agents/skills/` | any agent, all projects |
| `install.sh agents` | `AGENTS.md` only | Cursor, Zed, Amp, anything AGENTS.md-aware |

The Copilot instructions file applies automatically to `.pike`, `.rxml`, and anything under
`modules/`. Re-running is safe.

`lab/` is a development harness, not part of the install — clone the repo to use it.

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
passed: 73   failed: 0
```

Checks the module-signal counts, the full `MODULE_*` taxonomy, tag discovery in
`module.pike`, the `Roxen.pmod` response-helper signatures, the `CACHE()` and `QUERY()`
macros, and source encoding. Run it against your own Roxen tree to see where it differs
from upstream.

> Counts are pinned to the commit they were measured at
> (`6ed4566`). Override with `ROXEN_PIN` to re-measure against another revision.

## Getting Roxen running at all

[`lab/`](lab/) is a container with Pike 8.0.1116 and a real Roxen 6.3, used to verify these
skills against a running system. Building it surfaced several dead ends that present as a
silent exit with no diagnostic — the worst kind to debug:

- Debian/Ubuntu's `pike8.0-full` **has no `Regexp.PCRE`**, and Roxen hard-exits without it
- **Pike 8.0.1116 cannot build `Gz` against zlib 1.3** — and `Roxen.pmod` calls `Gz.File`
  at line 1064, so one missing module produced ~97 cascading errors
- `./start --program` **does not** boot Roxen; it replaces `roxenloader.pike`

[`lab/provision.sh`](lab/provision.sh) takes it all the way to a serving instance:

```
$ docker run --rm -p 8080:8080 pike-roxen-lab /lab/provision.sh
Roxen is serving on http://127.0.0.1:8080/ (401 until you authenticate)
Server: Roxen/6.3.1779-git
```

The last blocker was a **reserved word**: Roxen 6.3 declares a `db_schedules` column named
`offset`, which MariaDB 10.6 rejects unquoted — so the schema never initialises and the
boot dies later on a missing `roxen.dbs`, nowhere near the cause. Fixed upstream by 8.3.

The skill's *Getting a Working Roxen Environment* section has the full list, and
`verify.sh` asserts each claim against Roxen's source.

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
