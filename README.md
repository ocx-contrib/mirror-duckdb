# mirror-duckdb

OCX mirror for [DuckDB](https://github.com/duckdb/duckdb), the in-process
analytical SQL database. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [duckdb](https://github.com/duckdb/duckdb) | [`duckdb/mirror.yml`](duckdb/mirror.yml) | `ghcr.io/ocx-contrib/duckdb/duckdb` | [`ocx.sh/duckdb/duckdb`](https://index.ocx.sh/duckdb/duckdb) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

The GitHub org is the project's own brand, so the org names the namespace and
the tool names the package: `duckdb/duckdb`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
duckdb/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `duckdb/mirror.yml` does not restate it at all, which removes the
trap structurally.

## Two upstream release trains

DuckDB maintains **1.5.x** (current) and a **1.4.x LTS** line at the same time,
and they interleave *by publish date*:

| Tag | Published |
|---|---|
| v1.5.5 | 2026-07-22 |
| v1.5.4 | 2026-06-17 |
| **v1.4.5** | **2026-06-17** ← LTS, between two 1.5 releases |
| v1.5.3 | 2026-05-20 |

A "newest N by `published_at`" read therefore returns an *older* version
sorting between two newer ones. `tag_pattern` is anchored to the current train
(`^v(?P<version>1\.5\.\d+)$`), so the LTS line never enters the range and
ordering is by parsed semver within one train.

The two trains are also shaped differently: 1.4.x never shipped the `-musl`
variants this mirror declares — those start at v1.5.0 — so a pattern covering
both would 0-match two platforms across half the range. If the LTS line is ever
wanted, it is a separate package.

## Platforms

Both Linux arches are published **twice**, once per libc family:
`linux/{amd64,arm64}+libc.glibc` and `linux/{amd64,arm64}+libc.musl`.

That is not a stylistic choice. `os.features` states what an artifact
*requires of the host*, and all eight Linux artifacts (two arches × two
flavours × both ends of the range, 1.5.3 and 1.5.5) were byte-measured as
**dynamically linked**:

| Asset | Interpreter | libc in `DT_NEEDED` | Key |
|---|---|---|---|
| `duckdb_cli-linux-amd64.zip` | `/lib64/ld-linux-x86-64.so.2` | `libc.so.6` | `+libc.glibc` |
| `duckdb_cli-linux-arm64.zip` | `/lib/ld-linux-aarch64.so.1` | `libc.so.6` | `+libc.glibc` |
| `duckdb_cli-linux-amd64-musl.zip` | `/lib/ld-musl-x86_64.so.1` | `libc.musl-x86_64.so.1` | `+libc.musl` |
| `duckdb_cli-linux-arm64-musl.zip` | `/lib/ld-musl-aarch64.so.1` | `libc.musl-aarch64.so.1` | `+libc.musl` |

Neither flavour is static, so a bare key would be a false universality claim
and a glibc-only mirror would resolve onto musl hosts and die at `exec`.
Cross-checked live — the glibc build under `alpine:3.20` answers
`sh: /b/duckdb: not found`, which is the loader, not a missing file. The GLIBC
symbol floor is `GLIBC_2.25` on **both** arches (measured separately; the two
come off different toolchains and are not assumed symmetric).

### `libstdc++` on the musl legs

duckdb is C++, so every artifact also needs `libstdc++.so.6` and
`libgcc_s.so.1`. Measured on the real binary in the stock images:

| Image | Build | Stock result |
|---|---|---|
| `ubuntu:24.04` | glibc | `SELECT 1+1` → `2` — no setup needed |
| `fedora:40` | glibc | `SELECT 1+1` → `2` — no setup needed |
| `alpine:3.20` | musl | `Error loading shared library libstdc++.so.6: No such file or directory` |

So only the musl legs carry a `containers[].setup:` line —
`apk add --no-cache libstdc++`, the minimum that makes the artifact *load*.
`os.features` carries libc only, so this is a consumer-side prerequisite with
no declarable home in the spec; it is documented in `duckdb/CATALOG.md`.

### `.zip`, never `.gz`

Upstream ships both formats for every unix asset. The `.gz` is a **bare
single-file gzip** — a compressed ELF with no tar layer — which the pipeline
cannot unpack:

```
$ gzip -dc duckdb_cli-linux-amd64.gz | tar tf -
tar: This does not look like a tar archive
$ gzip -dc duckdb_cli-linux-amd64.gz | head -c4 | od -An -tx1
 7f 45 4c 46          ← ELF magic; no `ustar` at offset 257
```

`asset_type: binary` would *false-green* it — prepare exits 0 shipping still-
compressed bytes at mode 0755. Windows ships `.zip` only, so `.zip` is also the
one format spanning every platform and the whole range.

### End-anchored patterns

Every asset regex is anchored at **both** ends, and the trailing `$` is
load-bearing twice: without it `^duckdb_cli-linux-amd64\.zip` also prefix-
matches `duckdb_cli-linux-amd64-musl.zip` (ambiguous-match error), and
`^duckdb_cli-osx-…` reaches `duckdb_cli-osx-universal.zip`.

macOS is mirrored as the **arch-split pair**, not the universal fat binary —
each platform then gets only the slice it can run, at roughly half the bytes.
The `^duckdb_cli-` prefix also keeps the three *library* deliverables out:
`libduckdb-<plat>.zip` (C API shared library), `libduckdb-src.zip` (amalgamated
source) and `static-libs-<plat>.zip` (link-time archives) are not the CLI.

Resolution was verified **both ways on every in-range release** (1.5.3, 1.5.4,
1.5.5): each declared pattern matches exactly one asset of the 29 published,
every time. A pattern matching zero would be silently skipped rather than
reported, so this check is not optional.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `duckdb/mirror.yml` | hand | yes — see below |
| `duckdb/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `duckdb/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec duckdb/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`duckdb/metadata.json` declares `binaries: ["duckdb"]` by hand, and
`duckdb/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. The scan
only inspects an interface-visible `${installPath}/<dir>` PATH entry, and
duckdb's archives are **flat with a single entry**: `duckdb` (`duckdb.exe` on
Windows) at the archive root, no subdirectory to point one at, no `LICENSE` or
`README` beside it. With nothing to inspect the scan would pass green whatever
the archive contained, so `auto` and `verify` both fail spec load at exit 65
rather than offer a hollow check. The hand-written list is what the error
message itself directs, and it is as short as a list gets.

## The smoke test

A database's contract is the computed answer, so `duckdb/tests/smoke.star`
asserts values, not text: a `CREATE`/`INSERT`/`sum()` round-trip through the
in-memory storage engine, and a `read_csv()` aggregate over a file written into
the test scratch sandbox. Everything runs in-memory and offline.

The output mode is deliberate. Bare `duckdb -c …` renders a box-drawing table
(`-box` is the default `.mode`), which is decorated and would break a plain
substring assertion token by token; `-csv` and `-noheader -list` are byte-exact
and colourless, and both were measured with `od -c` on 1.5.3 and 1.5.5.

Two negative controls state what would go red. Invalid SQL must exit **1** with
empty stdout and the offending token echoed on stderr — so a binary that
printed a canned answer, or ignored `-c` entirely, cannot pass. And pointing
the same `read_csv()` call at a path that does not exist must fail — so the
aggregate above cannot have been constant-folded without opening the file.

`HOME` is overlaid onto the scratch root via `ocx.run(env=…)` (an overlay on
the composed env — `PATH` survives): duckdb resolves its CLI history file and
extension directory under `$HOME`, and container images routinely leave it
unset or unwritable.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md). Upstream's
release archives ship the executable alone with no `LICENSE` file, so MIT's
notice-retention condition is met by `NOTICE.md` and by the
`org.opencontainers.image.licenses` annotation on every published index. The
logo reproduces upstream's own mark, unmodified apart from scaling, solely to
identify the software being mirrored.
