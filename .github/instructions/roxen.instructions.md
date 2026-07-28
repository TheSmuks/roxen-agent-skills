---
applyTo: "**/*.pike,**/*.rxml,**/modules/**"
---

# Roxen Working Rules

High-frequency correctness rules for working in a [Roxen WebServer](https://www.roxen.com/)
codebase, in a format any coding agent can read. The full skill lives in `skills/`.

Verified against Roxen branches `6.3` and `8.3.806`; run `./verify.sh` to re-check every
number against real Roxen source.

## Recognising a module

- Identify a Roxen module by `constant module_type = MODULE_…;` (134 of 170 bundled module
  files), not by filename or directory.
- The inherit form is `inherit "module";` — **not** `inherit "module.pike"`, which appears
  in 1 of 170 files. Pike resolves the extensionless form to `module.pike`.
- `module_type` is a **bitfield**: `MODULE_LOCATION | MODULE_TAG` is legal. Read every bit
  before deciding what a module does.

## RXML tags

- Tag classes **must be named `Tag*`**. `query_tag_set()` finds them with
  `glob("Tag*", indices(this_object()))`, so a class named `GreetTag` is **silently
  skipped** — no error, the tag simply never exists. This is the most common reason a new
  tag "does nothing".
- Register a non-conforming class explicitly with `RXML.TagSet(this_module(), name, ({ … }))`.
- A tag is `inherit RXML.Tag` + `constant name` + a nested `class Frame` inheriting
  `RXML.Frame`, whose `do_return(RequestID id)` assigns `result` and returns `0`.

## Serving content

- `find_file(path, id)` returns `0` for "not mine", otherwise a response mapping from
  `Roxen.http_string_answer()`, `http_low_answer()`, `http_status()`, or `http_redirect()`.
- `query_location()` is the mount point; `path` in `find_file` is relative to it.
- Use `Roxen.http_rxml_answer()` when the returned content should itself be RXML-parsed.

## Request state

- `id->misc` is the per-request scratch mapping and the conventional channel for passing
  data between modules (804 uses across the bundled modules).
- `id->not_query` is the path without the query string; `id->variables` the form/query
  variables; `id->conf` the `Configuration` object.

## Encoding

- Roxen sources are **ISO-8859-1**. `grep` and `ripgrep` read them correctly with no
  special flags — this matters when **writing**: preserve the encoding rather than
  rewriting files as UTF-8.

## Pike

Roxen modules are Pike programs. Language and toolchain rules — module resolution,
testing, introspection, autodoc — are in
[pike-agent-skills](https://github.com/TheSmuks/pike-agent-skills).
