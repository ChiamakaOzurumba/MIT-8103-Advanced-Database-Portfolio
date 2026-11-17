# Portfolio 2 — Query Optimisation (7 marks)

**Student:** Chiamaka Ozurumba (2026/A/MIT/1005)

## Files

| File | Purpose |
| --- | --- |
| `01_analytical_queries.sql` | 8 analytical queries (joins, CTEs, recursive CTE, window functions, aggregates, anti-join) |
| `02_explain_analyze.sql` | `EXPLAIN (ANALYZE, BUFFERS)` before and after a targeted composite index |

## Queries

1. **Q1** — Asset count and status mix per collection (LEFT JOIN + `count(*) FILTER`).
2. **Q2** — Top assets by preservation event count (CTE + `RANK()` window).
3. **Q3** — Loan activity per user with running total (windowed aggregate of an aggregate).
4. **Q4** — Collection hierarchy (RECURSIVE CTE with depth).
5. **Q5** — Licence revenue per holder (JOIN + `sum` aggregate).
6. **Q6** — Monthly preservation events with month-over-month growth ratio (CTE + `lag` window).
7. **Q7** — Copies per site with availability rate (LEFT JOIN + filtered count).
8. **Q8** — Assets with no preservation event in the last 90 days (anti-join via `HAVING max(...) < ...`).

## EXPLAIN ANALYZE demo

The targeted query filters `preservation_event` on `outcome = 'FLAGGED'` and `event_date >= CURRENT_DATE - 60`, then groups by `asset_id`.

- **BEFORE** — only single-column indexes exist; the planner does a Seq Scan on the 62,000-row table.
- **AFTER** — a composite index `(outcome, event_date)` is created; the planner switches to an Index Scan reading only matching rows.

### Honest note

A full-table aggregate such as `SELECT outcome, count(*) FROM preservation_event GROUP BY outcome` has no selective predicate, so the planner correctly keeps a Seq Scan regardless of indexes — scanning the whole heap is cheaper than random index probes. This is shown explicitly at the end of `02_explain_analyze.sql`.

## Rules followed

- Every column in `SELECT` or `ORDER BY` is in `GROUP BY` or aggregated.
- No `generate_series` on time types; time stepping is done via integers added to a base date (see Portfolio 1 bulk load).
- `make_interval` arguments are cast to `int`.
- No `round(interval)`; growth is a `numeric` ratio.
- No direct index on `(timestamptz::date)`; if a timestamptz column needs to be indexed by Lagos date, the expression `(col AT TIME ZONE 'Africa/Lagos')::date` is used. (This portfolio's date filters are on the `DATE` column `event_date`, so the rule is satisfied directly.)

## Note

Drafted with AI assistance and will be tested and corrected before submission.
