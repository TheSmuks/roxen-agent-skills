#!/bin/sh
# Provision a Roxen 6 instance to the point where it actually serves HTTP.
#
# Run inside the lab container:
#   docker run --rm -p 8080:8080 -it pike-roxen-lab /lab/provision.sh
#
# Every step here exists because of a specific failure; the comments say which.
# Without them Roxen exits with no useful diagnostic.

set -eu

CONFDIR=${CONFDIR:-/tmp/rxconf}
PORT=${PORT:-8080}
ADMIN_USER=${ADMIN_USER:-administrator}
ADMIN_PASS=${ADMIN_PASS:-RoxenLab123}
SOCK="$CONFDIR/_mysql/socket"

cd /opt/roxen/server

say() { printf '\n=== %s ===\n' "$1"; }

# ---------------------------------------------------------------------------
say "1/4  seed Roxen's data directory"
# Roxen copies a template MySQL data directory on first run and writes my.cfg
# next to it. It fails at this point — that is expected; we only want the
# directory and the config it generates.
timeout 150 ./start -DALLOW_UNSUPPORTED_MYSQL --once --config-dir="$CONFDIR" \
  >/dev/null 2>&1 || true
[ -f "$CONFDIR/_mysql/my.cfg" ] || { echo "no my.cfg — Roxen never seeded the datadir"; exit 1; }

# ---------------------------------------------------------------------------
say "2/4  build a MariaDB-native privilege system"
# Roxen's template data directory cannot be used as-is on modern MariaDB, for
# two separate reasons:
#
#   * Its mysql.* system tables predate MariaDB 10.4, so privilege loading
#     fails outright.
#   * DBManager.pmod sets privileges by writing to mysql.user and mysql.db
#     directly. Since 10.4 mysql.user is a *view* over global_priv, so those
#     writes fail with "View 'mysql.user' references invalid table(s)", Roxen
#     never grants its own `rw` user, and every page becomes a 404.
#
# Repairing the template in place does not help — mariadb-upgrade cannot fix a
# schema this old, and running it under --skip-grant-tables leaves the view
# broken. So build a fresh, MariaDB-native datadir instead and create Roxen's
# users with GRANT, the supported interface. Roxen autocreates its own tables.
#
# Roxen's my.cfg must be supplied to mariadb-install-db: the template sets
# innodb-data-file-path=ibdata1:10M:autoextend, and without it install-db uses
# its own default and fails with "The Auto-extending data file './ibdata1' is of
# a different size".
pkill -f mariadbd 2>/dev/null || true
sleep 2
cp "$CONFDIR/_mysql/my.cfg" /tmp/roxen-my.cfg
rm -rf "$CONFDIR/_mysql"
mkdir -p "$CONFDIR/_mysql"
cp /tmp/roxen-my.cfg "$CONFDIR/_mysql/my.cfg"

mariadb-install-db --defaults-file="$CONFDIR/_mysql/my.cfg" --user=root \
  --datadir="$CONFDIR/_mysql" --auth-root-authentication-method=normal \
  >/tmp/install-db.log 2>&1 || { echo "mariadb-install-db failed"; tail -5 /tmp/install-db.log; exit 1; }

timeout 40 /usr/sbin/mariadbd \
  --defaults-file="$CONFDIR/_mysql/my.cfg" --socket="$SOCK" \
  --skip-external-locking --skip-name-resolve \
  --basedir=/usr --datadir="$CONFDIR/_mysql" >/dev/null 2>&1 &
sleep 9

mariadb --socket="$SOCK" -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS local;
CREATE DATABASE IF NOT EXISTS roxen;
CREATE USER IF NOT EXISTS 'rw'@'localhost';
CREATE USER IF NOT EXISTS 'ro'@'localhost';
GRANT ALL PRIVILEGES ON *.* TO 'rw'@'localhost' WITH GRANT OPTION;
GRANT SELECT ON *.* TO 'ro'@'localhost';
FLUSH PRIVILEGES;
SQL
echo "privilege system rebuilt; rw/ro granted"
mariadb --socket="$SOCK" -u root -e "SHUTDOWN;" >/dev/null 2>&1 || true
sleep 3

# ---------------------------------------------------------------------------
say "3/4  create the administration interface"
# A freshly booted Roxen with no configuration opens no ports and exits 50
# ("Failed to open any port"). bin/create_configif.pike creates the initial
# admin server. The prompts, in order: server name, port URL, admin user,
# password, password again, confirm.
printf '\nhttp://*:%s/\n%s\n%s\n%s\ny\n' \
  "$PORT" "$ADMIN_USER" "$ADMIN_PASS" "$ADMIN_PASS" \
  | timeout 200 ./start --program bin/create_configif.pike \
      --config-dir="$CONFDIR" >/dev/null 2>&1 || true
[ -d "$CONFDIR/_configinterface" ] || { echo "config interface was not created"; exit 1; }
echo "admin interface configured on port $PORT"

# ---------------------------------------------------------------------------
say "4/4  start Roxen"
# ./start forks and the parent returns immediately, and the first boot
# recompiles ("Removing old precompiled files"), so a fixed sleep races it.
# Poll the port instead.
./start -DALLOW_UNSUPPORTED_MYSQL --config-dir="$CONFDIR" >/tmp/roxen-run.log 2>&1 &

code=""
i=0
while [ "$i" -lt 60 ]; do
  code=$(curl -sS -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" 2>/dev/null || true)
  case "$code" in 401|200) break ;; esac
  i=$((i + 1))
  sleep 5
done

if [ "$code" = "401" ] || [ "$code" = "200" ]; then
  echo "Roxen is serving on http://127.0.0.1:$PORT/ (401 until you authenticate)"
  echo "  user: $ADMIN_USER   password: $ADMIN_PASS"
  curl -sS -m 10 -I "http://127.0.0.1:$PORT/" 2>/dev/null | grep -i '^server' || true
else
  echo "Roxen did not answer on port $PORT after $((i * 5))s"
  echo "--- start log ---"; tail -15 /tmp/roxen-run.log
  # Roxen writes the useful detail to its own debug log, not to stdout.
  echo "--- debug log ---"; tail -25 /opt/roxen/logs/debug/* 2>/dev/null | tail -25
  exit 1
fi
