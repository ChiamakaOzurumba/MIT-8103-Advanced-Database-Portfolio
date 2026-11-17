-- Portfolio 2 - Analytical queries (8 queries)
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- Rules followed:
--   * Every column in SELECT/ORDER BY is in GROUP BY or aggregated.
--   * No generate_series on time types (we step through integers elsewhere).
--   * make_interval args are cast to int (see seed/bulk files).
--   * No round(interval); growth is a numeric ratio.
--   * No direct index on (timestamptz::date); use (col AT TIME ZONE 'Africa/Lagos')::date.
\set ON_ERROR_STOP on
\pset pager off

\echo '==== Q1: Asset count and status mix per collection (JOIN + aggregate + FILTER) ===='
SELECT c.name AS collection_name,
       count(a.asset_id) AS asset_count,
       count(*) FILTER (WHERE a.status = 'ARCHIVED')   AS archived,
       count(*) FILTER (WHERE a.status = 'CATALOGUED') AS catalogued,
       count(*) FILTER (WHERE a.status = 'DRAFT')      AS draft
FROM archive_collection c
LEFT JOIN media_asset a ON a.collection_id = c.collection_id
GROUP BY c.collection_id, c.name
ORDER BY asset_count DESC, collection_name;

\echo '==== Q2: Top assets by preservation event count (CTE + window RANK) ===='
WITH pe_counts AS (
   SELECT asset_id, count(*) AS events
   FROM preservation_event
   GROUP BY asset_id
)
SELECT a.title,
       a.medium,
       pc.events,
       RANK() OVER (ORDER BY pc.events DESC) AS event_rank
FROM media_asset a
JOIN pe_counts pc ON pc.asset_id = a.asset_id
ORDER BY event_rank, a.title
LIMIT 10;

\echo '==== Q3: Loan activity per user with running total (JOIN + windowed aggregate) ===='
SELECT u.full_name,
       l.status,
       count(*) AS loan_count,
       sum(count(*)) OVER (PARTITION BY u.user_id ORDER BY l.status) AS running_total
FROM users u
JOIN loan l ON l.user_id = u.user_id
GROUP BY u.user_id, u.full_name, l.status
ORDER BY u.full_name, l.status;

\echo '==== Q4: Collection hierarchy (RECURSIVE CTE) ===='
WITH RECURSIVE hierarchy AS (
   SELECT collection_id, parent_collection_id, name, code, 0 AS depth
   FROM archive_collection
   WHERE parent_collection_id IS NULL
   UNION ALL
   SELECT c.collection_id, c.parent_collection_id, c.name, c.code, h.depth + 1
   FROM archive_collection c
   JOIN hierarchy h ON c.parent_collection_id = h.collection_id
)
SELECT depth, code, name
FROM hierarchy
ORDER BY depth, code;

\echo '==== Q5: Licence revenue per holder (JOIN + aggregate) ===='
SELECT lh.name AS holder,
       count(l.licence_id) AS licence_count,
       sum(l.fee_naira) AS total_naira
FROM licence_holder lh
JOIN licence l ON l.holder_id = lh.holder_id
GROUP BY lh.holder_id, lh.name
ORDER BY total_naira DESC NULLS LAST, holder;

\echo '==== Q6: Monthly preservation events with month-over-month growth (window) ===='
WITH monthly AS (
   SELECT date_trunc('month', event_date)::date AS month,
          count(*) AS events
   FROM preservation_event
   GROUP BY date_trunc('month', event_date)::date
),
with_lag AS (
   SELECT month, events,
          lag(events) OVER (ORDER BY month) AS prev_events
   FROM monthly
)
SELECT month,
       events,
       prev_events,
       CASE WHEN prev_events IS NULL OR prev_events = 0 THEN NULL
            ELSE round((events::numeric - prev_events) / prev_events::numeric, 4)
       END AS growth_ratio
FROM with_lag
ORDER BY month;

\echo '==== Q7: Copies per site with availability rate (JOIN + aggregate) ===='
SELECT s.site,
       count(c.copy_id) AS copies,
       count(*) FILTER (WHERE c.is_available) AS available,
       round(avg(CASE WHEN c.is_available THEN 1 ELSE 0 END)::numeric, 4) AS availability_rate
FROM storage_location s
LEFT JOIN asset_copy c ON c.location_id = s.location_id
GROUP BY s.location_id, s.site
ORDER BY copies DESC, site;

\echo '==== Q8: Assets with no preservation event in the last 90 days (anti-join via HAVING) ===='
SELECT a.title,
       a.medium,
       a.status,
       max(pe.event_date) AS last_event
FROM media_asset a
LEFT JOIN preservation_event pe ON pe.asset_id = a.asset_id
GROUP BY a.asset_id, a.title, a.medium, a.status
HAVING max(pe.event_date) IS NULL
    OR max(pe.event_date) < CURRENT_DATE - 90
ORDER BY last_event DESC NULLS LAST, a.title;
