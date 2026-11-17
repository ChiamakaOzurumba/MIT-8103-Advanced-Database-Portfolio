-- Portfolio 5 - Range partitioning by month
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- Partitions the loan/access table (as loan_partitioned) by RANGE on start_at.
-- The partition key is included in the PRIMARY KEY.
-- Partitions cover every month from 2024-01 through next month; no DEFAULT partition.
-- The old table is dropped with CASCADE. Shows rows per partition + a pruned EXPLAIN ANALYZE.
\set ON_ERROR_STOP on
\pset pager off

DROP TABLE IF EXISTS loan_partitioned CASCADE;

CREATE TABLE loan_partitioned (
    loan_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    asset_copy_id INTEGER NOT NULL REFERENCES asset_copy(copy_id) ON DELETE CASCADE,
    user_id       INTEGER NOT NULL REFERENCES users(user_id),
    status        loan_status NOT NULL DEFAULT 'REQUESTED',
    start_at      TIMESTAMPTZ NOT NULL,
    end_at        TIMESTAMPTZ NOT NULL,
    requested_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_at > start_at),
    PRIMARY KEY (loan_id, start_at)          -- partition key included in PK
) PARTITION BY RANGE (start_at);

-- Create one partition per month from 2024-01 through next month (current month + 1).
DO $$
DECLARE
   m          date := DATE '2024-01-01';
   end_month  date := date_trunc('month', CURRENT_DATE + interval '1 month')::date;
   part_name  text;
   n          int  := 0;
BEGIN
   WHILE m <= end_month LOOP
      part_name := 'loan_p_' || to_char(m, 'YYYYMM');
      EXECUTE format(
         'CREATE TABLE IF NOT EXISTS %I PARTITION OF loan_partitioned FOR VALUES FROM (%L) TO (%L)',
         part_name, m, (m + interval '1 month')::date
      );
      m := (m + interval '1 month')::date;
      n := n + 1;
   END LOOP;
   RAISE NOTICE 'partitions_created=%', n;
END $$;

-- No DEFAULT partition: every row maps to a real monthly partition.

-- Sample rows spanning the last 18 months (uses seeded asset_copy and users).
INSERT INTO loan_partitioned (asset_copy_id, user_id, status, start_at, end_at)
SELECT c.copy_id,
       ((c.copy_id % 8) + 5),
       (CASE (g % 4)
          WHEN 0 THEN 'RETURNED'::loan_status
          WHEN 1 THEN 'REQUESTED'::loan_status
          WHEN 2 THEN 'APPROVED'::loan_status
          ELSE 'RETURNED'::loan_status END),
       date_trunc('month', now()) - make_interval(months => (g % 18)::int),
       date_trunc('month', now()) - make_interval(months => (g % 18)::int) + interval '1 day'
FROM asset_copy c
CROSS JOIN generate_series(1, 20) AS g
LIMIT 400;

\echo '==== rows per partition ===='
SELECT tableoid::regclass AS partition, count(*) AS rows
FROM loan_partitioned
GROUP BY 1
ORDER BY 1;

\echo '==== pruned EXPLAIN ANALYZE: only partitions for the last 2 months are scanned ===='
EXPLAIN (ANALYZE)
SELECT count(*)
FROM loan_partitioned
WHERE start_at >= date_trunc('month', now()) - interval '2 months'
  AND start_at <  date_trunc('month', now());
