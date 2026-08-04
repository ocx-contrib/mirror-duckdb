# duckdb/tests/smoke.star — stable across upstream DuckDB releases.
# Asserts the contract (version shape, a real query answered with the right
# VALUE, and two negative controls), never help/version prose. See ocx.mirror
# testing-practices.md.
#
# duckdb is a database engine, so its contract is the computed answer: given
# hermetic input, produce the right number. Every query below runs against an
# in-memory database with no FILENAME argument — no network, no extension
# download, no state outside the test scratch sandbox.
#
# ⚠ OUTPUT MODE IS DELIBERATE, AND IT IS NOT THE DEFAULT. Bare `duckdb -c …`
# renders a box-drawing table (`-box` is the default `.mode`), which is
# decorated and locale-flavoured — a plain multi-word substring assertion
# against it is exactly the shape that breaks token by token. `-csv` and
# `-noheader -list` are byte-exact and colourless; both were measured with
# `od -c` on 1.5.3 AND 1.5.5, on the real bundle:
#
#   -noheader -list -c "CREATE TABLE … SELECT sum(n) FROM t;"  →  `1 0 \n`
#   -csv      -c "SELECT sum(n) AS total, count(*) AS rows …"  →  `total,rows\n10,4\n`
#
# ⚠ EXIT CODE ALONE PROVES NOTHING, so every positive assert is on the VALUE
# and is paired with a negative control below: a tool that merely echoed its
# argument, or one that answered every query with the same constant, passes an
# exit-0 check and fails these.
#
# `HOME` is overlaid onto the scratch root (`ocx.run(env=…)` is an OVERLAY on
# the composed env — PATH survives). duckdb resolves its CLI history file and
# its extension directory under `$HOME`/`%USERPROFILE%`, and container images
# routinely leave HOME unset or unwritable.

DUCKDB = "duckdb.exe" if ocx.target_platform.os == ocx.os.Windows else "duckdb"

ENV = {"HOME": ocx.scratch_root, "USERPROFILE": ocx.scratch_root}

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
# Upstream prints `v1.5.5 (Variegata) d8cdaa33fd` — the digits are the
# contract, the codename and the commit hash around them are not.
r_version = ocx.run(DUCKDB, "--version", env=ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3a: the storage engine, end to end ─────────────────────────────────
# CREATE → INSERT → aggregate in one in-memory session. `-noheader -list`
# strips every decoration, so the whole of stdout is the answer.
r_table = ocx.run(
    DUCKDB, "-noheader", "-list",
    "-c", "CREATE TABLE t(n INTEGER); INSERT INTO t VALUES (1),(2),(3),(4); SELECT sum(n) FROM t;",
    env=ENV,
)
expect.ok(r_table)
expect.eq(r_table.stdout.strip(), "10")

# ── Tier 3b: the CSV reader + aggregation on hermetic input ─────────────────
# Written into the scratch sandbox; `cwd` defaults to the scratch root, so the
# relative path in the SQL resolves. Both the column header the query names and
# the two computed values are asserted, so a scan that returned the wrong row
# count would fail even with the right sum.
ocx.write_file("data.csv", "n,label\n1,a\n2,b\n3,c\n4,d\n")

r_csv = ocx.run(
    DUCKDB, "-csv",
    "-c", "SELECT sum(n) AS total, count(*) AS rows FROM read_csv('data.csv')",
    env=ENV,
)
expect.ok(r_csv)
expect.contains(r_csv.stdout, "total,rows")
expect.contains(r_csv.stdout, "10,4")

# ── Negative control 1: the SQL parser must reject nonsense ─────────────────
# States what would go red. Without this, a binary that printed a canned answer
# to anything — or that ignored `-c` entirely — passes every assert above.
# Measured on 1.5.3 and 1.5.5: exit 1, EMPTY stdout, the offending token echoed
# on stderr (so the parser demonstrably read our statement, not a stub).
r_bad_sql = ocx.run(DUCKDB, "-csv", "-c", "SELEKT bogus FROM nowhere", env=ENV)
expect.eq(r_bad_sql.exit_code, 1)
expect.eq(r_bad_sql.stdout.strip(), "")
expect.contains(r_bad_sql.stderr, "SELEKT")

# ── Negative control 2: read_csv must actually touch the filesystem ─────────
# The Tier-3b assert would also pass if the sum had been constant-folded and
# the file never opened. Pointing the same call at a path that does not exist
# must fail. Measured: exit 1 on both ends of the range.
r_no_file = ocx.run(DUCKDB, "-csv", "-c", "SELECT * FROM read_csv('absent.csv')", env=ENV)
expect.eq(r_no_file.exit_code, 1)
