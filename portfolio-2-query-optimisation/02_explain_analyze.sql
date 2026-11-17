-- Portfolio 2 - EXPLAIN ANALYZE before and after targeted indexes
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- Demonstrates plan change from Seq Scan to Index Scan for a selective predicate,
-- and is honest that full-table aggregates stay Seq Scan.
\set ON_ERROR_STOP on
\pset pager off
\timing on

-- Drop any targeted index from a previous run so the BEFORE plan is reproducible.
DROP INDEX IF EXISTS idx_pe_outcome_date;
ANALYZE preservation_event;

\echo '==== BEFORE: no composite index on (outcome, event_date) ===='
\echo '---- Query: flagged preservation events in the last 60 days, per asset ----'
EXPLAIN (ANALYZE, BUFFERS)
SELECT asset_id, count(*) AS flagged_events
FROM preservation_event
WHERE outcome = 'FLAGGED'
  AND event_date >= CURRENT_DATE - 60
GROUP BY asset_id
ORDER BY flagged_events DESC, asset_id;

\echo ''
\echo '==== CREATE targeted composite index (outcome, event_date) ===='
CREATE INDEX idx_pe_outcome_date ON preservation_event (outcome, event_date);
ANALYZE preservation_event;

\echo ''
\echo '==== AFTER: composite index in place ===='
EXPLAIN (ANALYZE, BUFFERS)
SELECT asset_id, count(*) AS flagged_events
FROM preservation_event
WHERE outcome = 'FLAGGED'
  AND event_date >= CURRENT_DATE - 60
GROUP BY asset_id
ORDER BY flagged_events DESC, asset_id;

\echo ''
\echo '==== HONEST NOTE: full-table aggregate keeps a Seq Scan ===='
\echo '---- Query: total events per outcome (no predicate, whole table scanned) ----'
EXPLAIN (ANALYZE, BUFFERS)
SELECT outcome, count(*) AS total
FROM preservation_event
GROUP BY outcome
ORDER BY total DESC;
