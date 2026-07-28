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

## Status

With this image Roxen compiles cleanly — every module loads, and the boot proceeds past
module loading into `DBManager`. It does not yet serve requests: Roxen's template MySQL
data directory is incompatible with modern MariaDB's system tables. That remaining gap is
database provisioning, not Pike or Roxen code.
