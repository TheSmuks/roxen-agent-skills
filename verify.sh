#!/bin/sh
# Verify every claim in these skills against real Roxen source.
#
# By default this fetches pikelang/Roxen at the pinned commit the skills were
# measured against, so the numbers are reproducible. Point it at your own
# checkout instead with:
#
#   ROXEN_SRC=/path/to/Roxen ./verify.sh
#
# Exits non-zero if any documented fact no longer holds.

set -u

# The commit every count in the skills was measured against.
ROXEN_PIN=${ROXEN_PIN:-6ed456696088559c1b5e3dfdd2743ea49d43f8f6}

PASS=0
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

# count <label> <expected> <pattern>  — files under the module dirs matching pattern
count() {
  label=$1; want=$2; pat=$3
  got=$(find "$SRC/server/modules" "$SRC/server/more_modules" -name '*.pike' \
          -exec grep -l -F -- "$pat" {} + 2>/dev/null | wc -l | tr -d ' ')
  if [ "$got" = "$want" ]; then ok "$label ($got)"
  else bad "$label" "expected $want, got $got"; fi
}

has() { # has <label> <file> <substring>
  if grep -q -F -- "$3" "$2" 2>/dev/null; then ok "$1"; else bad "$1" "not found in $2"; fi
}

# ------------------------------------------------------------------- get source
if [ -n "${ROXEN_SRC:-}" ]; then
  SRC=$ROXEN_SRC
  echo "Roxen source: $SRC (supplied)"
  [ -d "$SRC/server/modules" ] || { echo "not a Roxen checkout: $SRC"; exit 1; }
  echo "  note: counts are pinned to $ROXEN_PIN; a different revision may differ"
else
  echo "Fetching pikelang/Roxen at $ROXEN_PIN ..."
  SRC=$TMP/Roxen
  mkdir -p "$SRC"
  ( cd "$SRC" && git init -q . \
      && git remote add origin https://github.com/pikelang/Roxen.git \
      && git fetch -q --depth 1 origin "$ROXEN_PIN" \
      && git checkout -q FETCH_HEAD ) \
    || { echo "fetch failed"; exit 1; }
  echo "Roxen source: pinned $ROXEN_PIN"
fi
echo

MODDIRS="$SRC/server/modules $SRC/server/more_modules"
TOTAL=$(find $MODDIRS -name '*.pike' | wc -l | tr -d ' ')
echo "module files: $TOTAL"
echo

# --------------------------------------------------------------- module signals
echo "module detection signals"
if [ "$TOTAL" = "170" ]; then ok "170 module .pike files"; else bad "170 module .pike files" "got $TOTAL"; fi
count "constant module_type"       134 'constant module_type'
count 'inherit "module"'           129 'inherit "module"'
count "#include <module.h>"        126 '#include <module.h>'
count "defvar("                     92 'defvar('
count 'inherit "module.pike"'        1 'inherit "module.pike"'
echo

# ------------------------------------------------------------------- module_type
echo "module_type taxonomy"
MC="$SRC/server/etc/include/module_constants.h"
for c in MODULE_ZERO MODULE_EXTENSION MODULE_LOCATION MODULE_URL MODULE_FILE_EXTENSION \
         MODULE_TAG MODULE_LAST MODULE_FIRST MODULE_AUTH MODULE_MAIN_PARSER \
         MODULE_TYPES MODULE_DIRECTORIES MODULE_PROXY MODULE_LOGGER MODULE_FILTER \
         MODULE_PROVIDER MODULE_USERDB MODULE_PROTOCOL MODULE_CONFIG MODULE_SECURITY \
         MODULE_EXPERIMENTAL; do
  if grep -q "constant $c " "$MC" 2>/dev/null; then ok "$c defined"; else bad "$c defined"; fi
done
has "MODULE_PARSER is an alias for MODULE_TAG" "$MC" "MODULE_PARSER            = MODULE_TAG"
echo

# ------------------------------------------------------------------- tag discovery
echo "RXML tag discovery"
MP="$SRC/server/base_server/module.pike"
has 'query_tag_set() globs "Tag*"' "$MP" 'glob ("Tag*", indices (this_object()))'
has "tags are filtered on is_RXML_Tag" "$MP" 'is_RXML_Tag'

CD="$SRC/server/modules/tags/countdown.pike"
has "countdown.pike inherits RXML.Tag" "$CD" 'inherit RXML.Tag;'
has "countdown.pike declares a nested Frame" "$CD" 'inherit RXML.Frame;'
has "countdown.pike uses do_return(RequestID id)" "$CD" 'array do_return(RequestID id)'
has "FLAG_EMPTY_ELEMENT is used" "$CD" 'RXML.FLAG_EMPTY_ELEMENT'

TAGC=$(grep -h -B3 'inherit RXML.Tag;' "$SRC"/server/modules/tags/*.pike 2>/dev/null \
        | grep -cE '^class Tag')
if [ "$TAGC" -ge 130 ]; then ok "tag classes are Tag*-named ($TAGC)"
else bad "tag classes are Tag*-named" "expected >=130, got $TAGC"; fi

has "explicit RXML.TagSet registration exists" \
  "$SRC/server/modules/tags/rxmltags.pike" 'RXML.TagSet ('
echo

# -------------------------------------------------------------- response helpers
echo "Roxen.pmod response helpers"
RP="$SRC/server/etc/modules/Roxen.pmod"
has "http_string_answer signature" "$RP" 'http_string_answer(string text, string|void type)'
has "http_low_answer signature"    "$RP" 'http_low_answer( int status_code, string data )'
has "http_status signature"        "$RP" 'http_status (int status_code,'
has "http_redirect signature"      "$RP" 'http_redirect( string url, RequestID|void id'
has "http_status_message exists"   "$RP" 'http_status_message (int status_code)'
echo

# ------------------------------------------------------------------------ macros
echo "macros and includes"
has "CACHE() lowers max cache" "$SRC/server/etc/include/roxen.h" \
  '#define CACHE(seconds) REQUESTID->lower_max_cache (seconds)'
has "QUERY() expands to query()" "$SRC/server/etc/include/module.h" \
  '#define QUERY(var)	query( #var )'
for t in TYPE_STRING TYPE_LOCATION TYPE_FLAG TYPE_DIR TYPE_PASSWORD; do
  has "$t defined" "$SRC/server/etc/include/module.h" "#define $t"
done
echo

# ---------------------------------------------------------------------- encoding
echo "source encoding"
FS="$SRC/server/modules/filesystems/filesystem.pike"
if file "$FS" 2>/dev/null | grep -q "ISO-8859"; then
  ok "Roxen sources are ISO-8859-1 (matters when writing)"
else
  bad "Roxen sources are ISO-8859-1" "file(1) reported: $(file "$FS" 2>&1)"
fi
# Real grep reads them fine — the skill must not claim otherwise.
if grep -q 'inherit' "$FS" 2>/dev/null; then
  ok "grep reads latin-1 Roxen sources without special flags"
else
  bad "grep reads latin-1 Roxen sources" "grep found nothing — re-check the encoding note"
fi
echo

# ------------------------------------------------- pike mechanics (if pike present)
if command -v pike >/dev/null 2>&1; then
  echo "pike mechanics"
  mkdir -p "$TMP/inh"
  echo 'string who() { return "inherit-ok"; }' > "$TMP/inh/module.pike"
  printf 'inherit "module";\nint main() { write("%%s\\n", who()); return 0; }\n' > "$TMP/inh/mymod.pike"
  if (cd "$TMP/inh" && pike mymod.pike 2>&1 | grep -q "inherit-ok"); then
    ok 'inherit "module" resolves module.pike'
  else
    bad 'inherit "module" resolves module.pike'
  fi
  if pike -e 'write("%O\n", glob("Tag*", ({"TagFoo","BarTag"})));' 2>&1 | grep -q "BarTag"; then
    bad 'glob("Tag*") rejects suffix names' "BarTag matched"
  else
    ok 'glob("Tag*") rejects suffix names like BarTag'
  fi
  echo
else
  echo "pike not installed — skipping Pike mechanics checks"
  echo
fi

# ------------------------------------------------------------------ repo health
echo "repo consistency"
HERE=$(cd "$(dirname "$0")" && pwd)
if [ -f "$HERE/AGENTS.md" ] && [ -f "$HERE/.github/instructions/roxen.instructions.md" ]; then
  if sed '1,4d' "$HERE/.github/instructions/roxen.instructions.md" \
       | diff -q - "$HERE/AGENTS.md" >/dev/null 2>&1; then
    ok "AGENTS.md and the Copilot instructions body are in sync"
  else
    bad "AGENTS.md and the Copilot instructions have drifted"
  fi
fi
if head -5 "$HERE/skills/roxen-modules/SKILL.md" | grep -q "name: roxen-modules"; then
  ok "skills/roxen-modules frontmatter name matches its directory"
else
  bad "skills/roxen-modules frontmatter name mismatch"
fi
echo

echo "-----------------------------------------"
printf 'passed: %d   failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
