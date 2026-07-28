# Eval

`verify.sh` proves the documented **facts** match Roxen's source. It does not prove the
skill changes what an agent does. This file is that check.

Each probe targets a specific misconception; the **"without"** column is the answer an
agent typically gives from general knowledge, and each one is wrong. Run by hand, compare,
score.

## Probes

### 1. Detecting a module

> "How do I find all the Roxen modules in this codebase?"

| | Answer |
|---|---|
| ❌ Without | Greps for `inherit "module.pike"` |
| ✅ With | Greps for `constant module_type` (134/170 files) or `inherit "module"` (129/170), and notes `inherit "module.pike"` appears in **1 of 170** files |

**Why it matters:** the wrong search misses ~99% of real modules and reports a Roxen
codebase as containing none.

### 2. Writing an RXML tag

> "Add an RXML tag called `<greet>` to this Roxen module."

| | Answer |
|---|---|
| ❌ Without | Defines `class GreetTag` or `class Greet` inheriting `RXML.Tag` |
| ✅ With | Names the class `TagGreet`, and explains that `query_tag_set()` discovers tags with `glob("Tag*", …)` so any other name is silently skipped |

**Why it matters:** the wrong name produces code that compiles, loads, and does nothing,
with no error anywhere. It is the single most expensive mistake in this domain.

### 3. Module type

> "This module declares `constant module_type = MODULE_LOCATION | MODULE_TAG;`. What is it?"

| | Answer |
|---|---|
| ❌ Without | Treats it as one type, usually the first |
| ✅ With | Recognises a bitfield: it both mounts at a path and contributes RXML tags |

### 4. Serving a response

> "Make this Roxen module return plain text at `/hello`."

| | Answer |
|---|---|
| ❌ Without | Returns a raw string, or invents a response object |
| ✅ With | `find_file()` returning `Roxen.http_string_answer("…", "text/plain")`, and `0` for paths it does not own |

### 5. Configuring a module

> "Set this module's mount point to `/files/` in the config."

| | Answer |
|---|---|
| ❌ Without | Edits a file under `configurations/` directly |
| ✅ With | Adds a `defvar("mountpoint", …, TYPE_LOCATION, …)` in `create()` and explains the value is set through the web configuration interface, which owns those files |

**Why it matters:** hand-edited config files get overwritten by the running server.

### 6. Searching the tree

> "Search this Roxen codebase for `module_type`."

| | Answer |
|---|---|
| ❌ Without | May add `-a` or `LC_ALL=C` "because Roxen files are binary" |
| ✅ With | Plain `grep` or `rg` — they read these ISO-8859-1 files correctly. Encoding matters when **writing**, not searching |

**Why it matters:** this one is here because a previous version of this skill got it
**wrong** and told agents to always use `grep -a`. `verify.sh` now asserts plain `grep`
works, so the false claim cannot return.

### 7. Passing data between modules

> "How should one Roxen module pass a value to another during a request?"

| | Answer |
|---|---|
| ❌ Without | Globals, or a module-level variable |
| ✅ With | `id->misc` — the per-request scratch mapping, and by far the most-used `RequestID` member (804 uses across the bundled modules) |

## Scoring

| Score | Meaning |
|-------|---------|
| 7/7 | Skill is working |
| 5–6 | Mostly working; check which section covers the miss |
| ≤4 | Skill is not being loaded — check install location and frontmatter |

## Known limits

- Hand-run, small sample. Detects gross regressions, not subtle quality.
- Written by the same author as the skill, so it tests what the skill covers, not what it
  omits.
- Nothing here exercises a **running** Roxen server; all probes are static reasoning.
  Verifying that generated modules actually load and serve would need a live instance.
