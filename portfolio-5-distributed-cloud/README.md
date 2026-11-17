# Portfolio 5 — Distributed and Cloud (6 marks)

**Student:** Chiamaka Ozurumba (2026/A/MIT/1005)

## Files

| File | Purpose |
| --- | --- |
| `01_partitioning.sql` | Range-partitions the loan/access table by month; partition key in PK; partitions cover all data dates plus next month; CASCADE drop; rows per partition; pruned EXPLAIN ANALYZE |
| `02_replica_setup.sh` | One script that builds a streaming replica on port 5433 on Ubuntu |
| `03_replica_tests.sql` | Primary/replica identity, write rejected on replica, marker replicated, lag from `pg_stat_replication`, marker cleanup |
| `cloud_design.md` | Short cloud design (NDPA + CBN residency, backups, DR, cost) with a Mermaid diagram |

## Partitioning (`01_partitioning.sql`)

`loan_partitioned` is a RANGE-partitioned table on `start_at` (TIMESTAMPTZ). The
PRIMARY KEY is `(loan_id, start_at)` so the partition key is included in every
unique constraint. A PL/pgSQL loop creates one partition per month from
`2024-01` through `CURRENT_DATE + 1 month`, so every row maps to a real
partition and nothing falls into a DEFAULT partition (there is none). The old
table is dropped with `DROP TABLE IF EXISTS loan_partitioned CASCADE`. The
script prints rows per partition and runs a pruned `EXPLAIN (ANALYZE)` whose
plan scans only the partitions for the last two months.

`make_interval` arguments are cast to `int`; no `round(interval)` is used.

## Replica setup (`02_replica_setup.sh`)

One bash script that:

1. Creates a `replicator` role (LOGIN REPLICATION) on the primary, idempotently.
2. Writes a minimal `/etc/postgresql/16/main/conf.d/replication.conf` with `wal_level = replica`, `max_wal_senders`, `listen_addresses`.
3. Inserts replication/trust lines at the TOP of `pg_hba.conf` with `sed -i '1i ...'` (local + 127.0.0.1 + ::1 for the `replicator` user); existing replicator lines are removed first so the script is idempotent.
4. Restarts the primary to apply WAL/HBA settings.
5. Recreates the replica data directory `/var/lib/postgresql/16/replica`, `chown postgres`, `chmod 700`.
6. Runs `pg_basebackup` with `PGPASSWORD` passed through `env PGPASSWORD=...` (trust auth is in effect, so the password is not actually used, but it is passed as required).
7. Writes a minimal `${REPLICA_DATA}/postgresql.conf` (port 5433, `hot_standby = on`).
8. Copies `pg_hba.conf` and `pg_ident.conf` from `/etc/postgresql/16/main/` into the replica data dir.
9. Starts the replica with `/usr/lib/postgresql/16/bin/pg_ctl -D ... -o "-p 5433"`.

All privileged PostgreSQL actions use `sudo runuser -u postgres -- ...`, never
`sudo -u postgres`. No `*` or `~` characters appear in any pasted command; `$HOME`
and exact file names are used throughout.

## Replica tests (`03_replica_tests.sql`)

Run on the primary (`psql -p 5432 -d mediaarchive -f 03_replica_tests.sql`). The
script uses `\c "port=5433 dbname=mediaarchive host=/var/run/postgresql"` to
switch to the replica and back. It shows:

- `current_setting('port')` and `pg_is_in_recovery()` on each side to identify PRIMARY vs REPLICA.
- A `CREATE TABLE` on the replica that is rejected (`cannot execute CREATE TABLE in a read-only transaction`).
- A `replica_marker` row written on the primary and then visible on the replica.
- Replication lag from `pg_stat_replication` on the PRIMARY only (no primary-only function is called on the replica).
- Deletion of the marker on the primary, verified gone on the replica.

## Cloud design (`cloud_design.md`)

Covers Nigerian data residency under the NDPA 2023 and the CBN guidance,
encrypted in-country backups (logical + physical + MongoDB + object storage),
DR with a Lagos standby and an Abuja async mirror (RPO <= 5 min, RTO <= 1 hr),
and an indicative monthly cost in the USD 300-450 range. Includes a Mermaid
architecture diagram.

## Note

Drafted with AI assistance and will be tested and corrected before submission.
