-- Portfolio 5 - Replica tests
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- Run on the PRIMARY (port 5432):
--   psql -p 5432 -d mediaarchive -f portfolio-5-distributed-cloud/03_replica_tests.sql
-- The script uses \c to switch to the replica (port 5433) for read-only and
-- write-rejection checks, then back to the primary for lag and cleanup.
-- Primary-only functions (pg_stat_replication, pg_current_wal_lsn) are NEVER
-- called on the replica.
\set ON_ERROR_STOP off
\pset pager off

\echo '==== Step 1: identify THIS server ===='
SELECT current_setting('port') AS port,
       pg_is_in_recovery()     AS in_recovery,
       CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END AS role;

\echo '==== Step 2: connect to the REPLICA on port 5433; a write must be rejected ===='
\c "port=5433 dbname=mediaarchive host=/var/run/postgresql"
SELECT current_setting('port') AS port,
       pg_is_in_recovery()     AS in_recovery,
       CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END AS role;
CREATE TABLE replica_reject_test (id int);
-- expected error: ERROR: cannot execute CREATE TABLE in a read-only transaction

\echo '==== Step 3: switch back to PRIMARY, write a marker row ===='
\c "port=5432 dbname=mediaarchive host=/var/run/postgresql"
CREATE TABLE IF NOT EXISTS replica_marker (id int PRIMARY KEY, note text);
INSERT INTO replica_marker VALUES (1, 'replication marker from primary')
ON CONFLICT (id) DO UPDATE SET note = EXCLUDED.note;
SELECT * FROM replica_marker;

\echo '==== Step 4: check the marker has streamed to the REPLICA (wait 2 s for WAL replay) ===='
SELECT pg_sleep(2);
\c "port=5433 dbname=mediaarchive host=/var/run/postgresql"
SELECT count(*) AS marker_rows_on_replica FROM replica_marker;

\echo '==== Step 5: replication lag from pg_stat_replication (PRIMARY only) ===='
\c "port=5432 dbname=mediaarchive host=/var/run/postgresql"
SELECT application_name,
       state,
       sync_state,
       pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
       pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1024 AS lag_kb
FROM pg_stat_replication;

\echo '==== Step 6: delete the marker on PRIMARY, verify it is gone on REPLICA ===='
DELETE FROM replica_marker WHERE id = 1;
SELECT count(*) AS marker_rows_on_primary FROM replica_marker;
SELECT pg_sleep(2);
\c "port=5433 dbname=mediaarchive host=/var/run/postgresql"
SELECT count(*) AS marker_rows_on_replica FROM replica_marker;
