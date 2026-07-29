# Lab

A container with Pike 8.0.1116 and a real Roxen 6.3 checkout, used to verify the claims
in these skills against a running system rather than against fixtures.

```bash
docker build -t pike-roxen-lab .
docker run --rm -it pike-roxen-lab
```

The image **fails to build** if Pike lacks anything Roxen hard-requires, which is the
point: those requirements are otherwise discovered as a silent `_exit(0)` at Roxen
startup, with no message saying which one was missing.

## What building this established

Each of these was a real dead end, diagnosed by running it:

- **Roxen 6 wants Pike 8.0 or newer.** It says so itself. A newer Pike is not needed —
  a version mismatch is the wrong first guess.
- **Debian/Ubuntu's `pike8.0-full` has no `Regexp.PCRE`.** It ships the documentation for
  it but not the module, and Roxen hard-exits without it. Pike must be built with
  `libpcre3-dev` present.
- **Pike 8.0.1116 cannot build `Gz` against zlib 1.3.** The header check passes and the
  run-test fails:
  ```
  zlib 1.2.11 -> checking working libz... yes
  zlib 1.3    -> checking working libz... no
  ```
  `Gz.pmod` is a stub requiring the C binding, so it silently does not load, and
  `Roxen.pmod` calls `Gz.File` at line 1064. That single missing module produced ~97
  cascading errors and stopped the boot. This is why the base here is 22.04, not 24.04.
- **Roxen can use a system MariaDB** via `server/mysql-location.txt`, and
  `-DALLOW_UNSUPPORTED_MYSQL` gets past the version check. Its seeded template data
  directory still predates modern MariaDB's system tables, which is a separate hurdle.
- **`./start --program` does not boot Roxen.** It replaces `roxenloader.pike` rather than
  running after it, so the runtime constants never exist. With roxenloader running,
  `Roxen.pmod` compiles; under `--program` it does not.

- **`mysql.user` is a view on MariaDB 10.4+.** `DBManager.pmod` grants Roxen's own users by
  writing to `mysql.user`/`mysql.db` directly, which that view rejects. Roxen then never
  grants its `rw` user and every page becomes a 404 with unparsed RXML — a symptom that
  looks like an RXML fault and is really a privilege one. Create the users with `GRANT`
  before starting Roxen. Do *not* run `mariadb-upgrade` under `--skip-grant-tables` while
  investigating; that breaks the view in a different way and produces the same symptom.

## Status

Roxen serves, and a module written against Roxen's APIs runs inside it.

```bash
docker build -t pike-roxen-lab .
docker run --rm pike-roxen-lab /lab/provision.sh     # Roxen answering HTTP
docker run --rm pike-roxen-lab /lab/load-module.sh   # + a real module loaded
```

`load-module.sh` installs [`TestLab.pike`](TestLab.pike) — a
`MODULE_LOCATION | MODULE_TAG` module — enables it by adding one line to the
configuration's `EnabledModules` region, restarts, and fetches `/labtest/probe`:

```
HTTP/1.1 200 OK
Server: Roxen/6.3.1779-git

LABTEST OK
encoded=([ /* 2 elements */  &#34;a&#34;: 1, &#34;b&#34;: ({ 2, 3 }) ])
not_query=/labtest/probe
misc_is_mapping=1
```

The `&#34;` matters: it is `Roxen.html_encode_string` encoding the quotes produced by
`sprintf("%O", …)`. That call is the one that cannot be checked outside a booted Roxen,
and here it is running inside one — together with `id->not_query`, `id->misc` and
`Roxen.http_string_answer`.

The script asserts on that content rather than on the status code. Checking only the
status is how an earlier version of this lab reported a 404 page as a working admin
interface.
