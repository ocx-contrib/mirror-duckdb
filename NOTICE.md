# NOTICE

This repository packages and redistributes upstream software published by the
[DuckDB](https://github.com/duckdb/duckdb) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

Each package's logo in this repository reproduces the **upstream project's own
mark** (`logo/DuckDB_Logo-stacked.svg` from the upstream repository) at 512 px,
unmodified apart from scaling, solely to identify the software being mirrored.
No endorsement or affiliation is implied, and no trademark right is claimed.
DuckDB is a trademark of the Stichting DuckDB Foundation.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `duckdb` | `ghcr.io/ocx-contrib/duckdb/duckdb` | `MIT` |

---

## `duckdb`

Upstream: <https://github.com/duckdb/duckdb>
Published to `ghcr.io/ocx-contrib/duckdb/duckdb`.

| Component | SPDX | Holder |
|---|---|---|
| DuckDB CLI (`duckdb`) | **MIT** | Copyright 2018-2026 Stichting DuckDB Foundation |

Verified at the Phase 1.5 license gate, against the repository blob rather than
GitHub's cached SPDX field alone:

```
$ gh api repos/duckdb/duckdb/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE","spdx":"MIT"}

$ gh api repos/duckdb/duckdb/contents/LICENSE --jq .content | base64 -d | head -1
Copyright 2018-2026 Stichting DuckDB Foundation
```

It is the unmodified MIT text — no added clause, field-of-use restriction or
non-commercial rider. MIT grants redistribution of the compiled binary on the
sole condition that the copyright notice and the permission notice accompany
all copies or substantial portions of the software.

**Upstream's `duckdb_cli-*` release archives contain the executable alone** —
verified with `unzip -l` on all eight declared assets of v1.5.5 and the four
Linux assets of v1.5.3: exactly one entry each, `duckdb` (`duckdb.exe` on
Windows), with no `LICENSE` file beside it. The notice-retention condition is
therefore met **here** rather than by the archive contents: the attribution
above reproduces it, the canonical text is
<https://github.com/duckdb/duckdb/blob/main/LICENSE>, and every published
manifest carries `org.opencontainers.image.licenses: MIT` alongside an
`org.opencontainers.image.source` annotation pointing at this repository.

The published binaries statically link third-party C and C++ libraries under
permissive licenses, vendored in upstream's `third_party/` tree of the tagged
source for each mirrored version.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
