# Screenshots to capture

Capture each of these into this folder (PNG, named as below) when running the portfolio on GitHub Codespaces. Each screenshot must show real terminal output, not a placeholder.

1. `01-setup.png` — output of `bash setup.sh` (role + db + extensions created).
2. `02-schema.png` — `psql -d mediaarchive -f portfolio-1-database-design/01_schema.sql`.
3. `03-indexes.png` — `02_indexes.sql` run, then `\di+` listing > 30 indexes.
4. `04-seed.png` — `03_seed_data.sql` and a `SELECT count(*)` from a few tables.
5. `05-bulk.png` — `04_bulk_data.sql`; `SELECT count(*) FROM preservation_event;` showing >= 60,000.
6. `06-constraints.png` — `05_constraint_tests.sql`; notices show 10 PASS (intended failure) + 1 PASS (control).
7. `07-queries.png` — `01_analytical_queries.sql` output for all 8 queries.
8. `08-explain-before.png` — Seq Scan plan from `02_explain_analyze.sql` BEFORE indexes.
9. `09-explain-after.png` — Index Scan plan AFTER indexes.
10. `10-transactions.png` — `01_transactions.sql` (commit, rollback, savepoint).
11. `11-race-log.png` — head of `race_demos_output.log` covering all 6 parts.
12. `12-mongo-collections.png` — `mongosh mediaarchive --quiet 01_setup_collections.js` plus `db.getCollectionNames()`.
13. `13-mongo-bulk.png` — `02_bulk_data.js`; `db.catalogue.countDocuments()` showing >= 40,000.
14. `14-mongo-agg.png` — `03_aggregations.js` pipeline outputs.
15. `15-mongo-index-demo.png` — `04_index_demo.js` before (COLLSCAN) / after (IXSCAN) with `docsExamined` and `executionTimeMillis`.
16. `16-partitioning.png` — `01_partitioning.sql`; rows per partition and pruned EXPLAIN ANALYZE.
17. `17-replica-setup.png` — `bash 02_replica_setup.sh` end of run.
18. `18-replica-tests.png` — `03_replica_tests.sql`; primary/replica, write rejected, marker replicated, lag.
19. `19-cloud-design.png` — `cloud_design.md` rendered Mermaid diagram.
