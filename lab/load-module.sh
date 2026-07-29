#!/bin/sh
# Load lab/TestLab.pike into a provisioned Roxen and verify it serves.
#
#   docker run --rm pike-roxen-lab /lab/load-module.sh
#
# Proves what ./start --program cannot: that code calling Roxen APIs compiles
# *and runs* against the real runtime, not merely against Roxen's module path.

set -eu
CONFDIR=${CONFDIR:-/tmp/rxconf}
PORT=${PORT:-8080}
CFG="$CONFDIR/Administration_Interface"

cd /opt/roxen/server
cp /lab/TestLab.pike modules/TestLab.pike

/lab/provision.sh >/tmp/provision.log 2>&1 || {
  echo "provisioning failed"; tail -15 /tmp/provision.log; exit 1; }

# Modules are enabled by a line in the configuration's EnabledModules region.
# No admin UI needed — the configuration is just a file.
if ! grep -q 'TestLab#0' "$CFG"; then
  sed -i "s|<region name='EnabledModules'>|<region name='EnabledModules'>\n  <var name='TestLab\#0'> <int>1</int> </var>|" "$CFG"
  echo "enabled TestLab#0 in $CFG"
fi

pkill -f roxenloader 2>/dev/null || true
sleep 5
./start -DALLOW_UNSUPPORTED_MYSQL --config-dir="$CONFDIR" >/tmp/roxen-run.log 2>&1 &

i=0
while [ "$i" -lt 40 ]; do
  c=$(curl -sS -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" 2>/dev/null || true)
  case "$c" in 401|200) break ;; esac
  i=$((i + 1)); sleep 5
done

echo
echo "=== GET /labtest/probe ==="
body=$(curl -sS -m 20 -u administrator:RoxenLab123 "http://127.0.0.1:$PORT/labtest/probe" 2>&1)
echo "$body"

echo
# html_encode_string must have turned sprintf's quotes into entities.
if printf '%s' "$body" | grep -q 'LABTEST OK' &&
   printf '%s' "$body" | grep -q '&#34;' &&
   printf '%s' "$body" | grep -q 'not_query=/labtest/probe' &&
   printf '%s' "$body" | grep -q 'misc_is_mapping=1'; then
  echo "PASS: the module served, and Roxen.html_encode_string, id->not_query"
  echo "      and id->misc all resolved inside the running server."
else
  echo "FAIL: module did not serve as expected"
  exit 1
fi
