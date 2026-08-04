---
title: duckdb
description: In-process analytical SQL database — query CSV, JSON and Parquet files directly from a single self-contained CLI, no server and no setup
keywords: duckdb,sql,database,olap,analytics,parquet,csv,json,columnar,embedded,data-engineering,cli
---

# duckdb

[DuckDB](https://duckdb.org) is an in-process analytical database — the OLAP
counterpart to SQLite. There is no server, no daemon and no configuration: the
CLI opens a database file (or an in-memory one when you name none) and answers
SQL directly. Its vectorized columnar engine is built for aggregation over
large scans, and it reads CSV, JSON and Parquet files *as tables* without an
import step, so `SELECT … FROM 'data/*.parquet'` works on the files where they
already sit.

## What's included

- **duckdb** — the CLI shell. Run it interactively, or non-interactively with
  `-c "<SQL>"` / `-f script.sql`. Output modes cover `-csv`, `-json`,
  `-jsonlines`, `-markdown`, `-line`, `-list` and the default `-box`; combine
  with `-noheader`, `-separator` and `-nullvalue` for machine-readable output.
  It exits **1** on a SQL or file error and 0 on success.

The release asset is the executable alone — a single self-contained binary with
the query engine, the CSV/JSON/Parquet readers and the storage layer compiled
in. No `LICENSE` or `README` accompanies it in the archive; upstream's MIT
notice is retained in this mirror's `NOTICE.md`.

## Runtime requirements

DuckDB is C++, and the published Linux binaries link the system C++ runtime
dynamically. Two Linux flavours are mirrored — a glibc build
(`linux/amd64+libc.glibc`, `linux/arm64+libc.glibc`) and a musl build
(`…+libc.musl`) — and OCX resolves the right one for the host automatically.

Beyond libc, both need **`libstdc++.so.6`** and **`libgcc_s.so.1`** present.
Mainstream distributions ship these already (verified on stock `ubuntu:24.04`
and `fedora:40`), but a minimal musl userland does not — on Alpine, install
them first:

```sh
apk add --no-cache libstdc++
```

`os.features` records the libc family only, so this is the one host
prerequisite the package cannot declare for you.

Some functionality (`httpfs`, `ui`, community extensions) downloads an
extension on first use and therefore needs network access; nothing in the core
CLI does.

## Usage

```sh
# answer one query and exit, machine-readable
duckdb -csv -c "SELECT count(*) FROM read_csv('events.csv')"
```

```sh
# query Parquet where it lies — no import, no schema declaration
duckdb -c "SELECT country, sum(amount) FROM 'sales/*.parquet' GROUP BY 1 ORDER BY 2 DESC"
```

```sh
# persist to a database file, then run a script against it
duckdb warehouse.duckdb -f build.sql
```

## Links

- [duckdb.org](https://duckdb.org)
- [DuckDB on GitHub](https://github.com/duckdb/duckdb)
- [SQL documentation](https://duckdb.org/docs/stable/sql/introduction)
- [CLI reference](https://duckdb.org/docs/stable/clients/cli/overview)
