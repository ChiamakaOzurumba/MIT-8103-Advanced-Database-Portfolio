# CHANGES (testing and fixes)

The project was run end to end in a GitHub-Codespaces-like environment (PostgreSQL 16, MongoDB, non-root user). These problems were found and fixed.

| # | File | Problem when run | Fix | Tested result |
|---|------|------------------|-----|---------------|
| 1 | portfolio-1/02_indexes.sql | `ON lower(users.email)` is invalid syntax (3 indexes) | Written as `ON users (lower(email))` | 68 indexes created |
| 2 | portfolio-1/01_schema.sql and 03_seed_data.sql | Seed inserts explicit ids into `GENERATED ALWAYS` identity columns | Identity columns are now `BY DEFAULT`; sequences are moved past the seeded ids after the seed | Seed and 62,000-row bulk load work |
| 3 | portfolio-1/01_schema.sql | The schema is dropped and recreated, which removed the `btree_gist` extension the exclusion constraint needs | Schema creates `btree_gist` again | Exclusion demo works |
| 4 | portfolio-3/race_demos.py | Part 4 (SERIALIZABLE retry) waited forever on a thread barrier on the retry | Only the first attempt waits for the other thread | Part 4 completes, one loan inserted |
| 5 | portfolio-3/race_demos.py | Part 6 fixed-order case waited forever (the second thread was blocked on the row lock) | Barrier wait has a 2 s timeout | Deadlock (40P01) shown, fixed order commits |
| 6 | portfolio-3/race_demos.py | A rerun failed on a leftover fixture row | Fixture is deleted at the start | Demo re-runnable |
| 7 | portfolio-3/race_demos.py | Connected as role `mediaarchive`, which has no matching Linux user (peer auth) | Connects as the current user over the Unix socket | Works in Codespaces |
| 8 | portfolio-4/01_setup_collections.js | `$jsonSchema` keyword `const` is not supported by MongoDB | Replaced with `enum` (still `oneOf`) | Collections created, validators active |
| 9 | portfolio-5/03_replica_tests.sql | Marker table was read on the replica before it had replayed | 2 s wait before the replica checks | Marker arrives and is removed on the replica |
| 10 | setup.sh, runall.sh | setup.sh installed packages that do not exist (`postgresql-contrib-16`, MongoDB without its repo); runners hid failures | Rewrote setup.sh; added `runall.sh` (P1 to P5, each committed) and `collect_results.sh` | Clean run, ends with ALL DONE |

Expected messages that are not errors: "ERROR: cannot execute CREATE TABLE in a read-only transaction" (proves the replica is read-only), "40P01 deadlock detected" (Part 6 demo), "23505", "23P01" and "40001" in the race demos.
