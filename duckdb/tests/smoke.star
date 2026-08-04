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
# ⚠ THE BINARY PRINTS AN UNSOLICITED BANNER TO **STDOUT** ON ONE DECLARED
# PLATFORM. darwin/amd64 is tested on the arm64 `macos-14` runner under
# Rosetta 2 (GitHub's native macos-13 Intel pool is exhausted and deadlocks
# push), and duckdb reads `sysctl.proc_translated` and emits, colourised, to
# stdout, before any result:
#
#   WARNING:
#   OSX binary translation ('Rosetta') detected. Running DuckDB through Rosetta
#   will cause a significant performance degradation. …
#
# There is NO suppression switch — `strings` on the osx-amd64 binary lists
# DUCKDB_EDITOR / _FIELD_IDE / _FILE / _HISTORY / _PAGER / _TYPE and nothing
# else; the warning is unconditional under translation. A byte-exact
# `expect.eq(r.stdout.strip(), "10")` therefore passes on five platforms and
# reds on the sixth, having found a real artifact that works perfectly.
#
# The fix is NOT to loosen the assertion. Every query below tags its result
# with a marker DuckDB itself concatenates in SQL (`'OCXSMOKE=' || …`), and the
# assertion is the COUNT of that marker: exactly one on a correct answer,
# exactly zero when the statement must fail. A prepended banner cannot change
# a substring count, the marker cannot collide with a version number or a URL,
# and the column is aliased (`AS r`) so the header row does not repeat the
# expression text and inflate the count to 2.
#
# ⚠ OUTPUT MODE IS DELIBERATE, AND IT IS NOT THE DEFAULT. Bare `duckdb -c …`
# renders a box-drawing table (`-box` is the default `.mode`), which is
# decorated and locale-flavoured. `-csv` and `-noheader -list` are byte-exact
# and colourless; both were measured with `od -c` on 1.5.3 AND 1.5.5:
#
#   -noheader -list …'OCXSMOKE=' || sum(n) AS r…   →  `OCXSMOKE=10\n`
#   -csv      …'OCXSMOKE=' || sum(n) || '/' || count(*) AS r…
#                                                  →  `r\nOCXSMOKE=10/4\n`
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

# Concatenated by DuckDB into every result row. Nothing else in duckdb's own
# output — banner, warning, header, URL, version string — contains it.
MARK = "OCXSMOKE="

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
# Upstream prints `v1.5.5 (Variegata) d8cdaa33fd` — the digits are the
# contract, the codename and the commit hash around them are not.
r_version = ocx.run(DUCKDB, "--version", env=ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3a: the storage engine, end to end ─────────────────────────────────
# CREATE → INSERT → aggregate in one in-memory session.
r_table = ocx.run(
    DUCKDB, "-noheader", "-list",
    "-c", "CREATE TABLE t(n INTEGER); INSERT INTO t VALUES (1),(2),(3),(4); SELECT 'OCXSMOKE=' || sum(n) AS r FROM t;",
    env=ENV,
)
expect.ok(r_table)
# Exactly one result row …
expect.eq(r_table.stdout.count(MARK), 1)
# … and its value is the sum of the four rows inserted. A build that returned
# the wrong number, or more than one row, fails here.
expect.eq(r_table.stdout.count(MARK + "10"), 1)

# ── Tier 3b: the CSV reader + aggregation on hermetic input ─────────────────
# Written into the scratch sandbox; `cwd` defaults to the scratch root, so the
# relative path in the SQL resolves. Both the sum and the row count are folded
# into the one marked value, so a scan that read the wrong number of rows fails
# even when the sum happens to be right.
ocx.write_file("data.csv", "n,label\n1,a\n2,b\n3,c\n4,d\n")

r_csv = ocx.run(
    DUCKDB, "-csv",
    "-c", "SELECT 'OCXSMOKE=' || sum(n) || '/' || count(*) AS r FROM read_csv('data.csv')",
    env=ENV,
)
expect.ok(r_csv)
expect.eq(r_csv.stdout.count(MARK), 1)
expect.eq(r_csv.stdout.count(MARK + "10/4"), 1)

# ── Negative control 1: the SQL parser must reject nonsense ─────────────────
# States what would go red. Without this, a binary that printed a canned answer
# to anything — or that ignored `-c` entirely — passes every assert above. The
# statement is the marked SELECT above with one letter changed, so validity is
# the only difference. Measured on 1.5.3 and 1.5.5: exit 1, NO marker on
# stdout, the offending token echoed on stderr (so the parser demonstrably read
# our statement rather than being a stub).
r_bad_sql = ocx.run(DUCKDB, "-csv", "-c", "SELEKT 'OCXSMOKE=' || 1 AS r", env=ENV)
expect.eq(r_bad_sql.exit_code, 1)
expect.eq(r_bad_sql.stdout.count(MARK), 0)
expect.contains(r_bad_sql.stderr, "SELEKT")

# ── Negative control 2: read_csv must actually touch the filesystem ─────────
# The Tier-3b assert would also pass if the sum had been constant-folded and
# the file never opened. Pointing the same call at a path that does not exist
# must fail and must emit no marked row. Measured: exit 1 on both ends.
r_no_file = ocx.run(
    DUCKDB, "-csv",
    "-c", "SELECT 'OCXSMOKE=' || count(*) AS r FROM read_csv('absent.csv')",
    env=ENV,
)
expect.eq(r_no_file.exit_code, 1)
expect.eq(r_no_file.stdout.count(MARK), 0)
