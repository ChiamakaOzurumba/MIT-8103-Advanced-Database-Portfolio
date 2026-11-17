# Portfolio 3 — Transactions and Concurrency (7 marks)

**Student:** Chiamaka Ozurumba (2026/A/MIT/1005)

## Files

| File | Purpose |
| --- | --- |
| `01_transactions.sql` | Committed transaction, rolled-back transaction, savepoint recovery, `set_config`/`current_setting` demo |
| `race_demos.py` | Threaded psycopg2 race demos across 6 parts (two real sessions, no `pg_sleep`, no hand pasting) |
| `race_demos_output.log` | Template; overwritten by the script when run. Paste the real log before submission. |

## `01_transactions.sql`

- **T1** — `BEGIN ... INSERT ... COMMIT`; the row persists.
- **T2** — `BEGIN ... INSERT ... ROLLBACK`; the row is not visible.
- **T3** — `BEGIN ... INSERT ... SAVEPOINT ... DO $$ RAISE EXCEPTION ... EXCEPTION WHEN OTHERS ... END $$ ... ROLLBACK TO SAVEPOINT ... INSERT ... COMMIT`; the pre-savepoint and post-savepoint rows survive, the error inside the `DO` block is caught.
- **T4** — `SELECT set_config('ndma.flag','on',false)` then a `DO` block reads it with `current_setting('ndma.flag')`. No psql `:variables` are used inside `DO` blocks.

## `race_demos.py`

Two real psycopg2 sessions driven by `threading.Thread`. A `threading.Barrier(2)` releases both threads together so they race genuinely. Each part resets its data first via `clear_loans`.

### Part 1 — the bug
No overlap constraint. Two threads each insert an `APPROVED` loan for the same `RACE-COPY`. Both commit. **Double lending.**

### Part 2 — UNIQUE fix
A partial unique index `ux_loan_active_race ON loan(asset_copy_id) WHERE status IN ('APPROVED','ACTIVE')` is added. The second thread to commit gets SQLSTATE `23505` (unique_violation).

### Part 3 — OUR TECHNIQUE (unique to this student)
An **EXCLUSION CONSTRAINT with `btree_gist`** is added:

```sql
ALTER TABLE loan ADD CONSTRAINT loan_no_overlap
EXCLUDE USING gist (
   asset_copy_id WITH =,
   tstzrange(start_at, end_at) WITH &&
);
```

Two loans for the same copy whose `[start_at, end_at)` ranges overlap cannot both exist. The second thread gets SQLSTATE `23P01` (exclusion_violation). The extension is created in `setup.sh`:

```bash
sudo runuser -u postgres -- psql -d mediaarchive -c "CREATE EXTENSION IF NOT EXISTS btree_gist"
```

### Part 4 — SERIALIZABLE retry on 40001
Both sessions run at `SERIALIZABLE`. Each reads for an existing APPROVED loan, then inserts. The loser at commit gets SQLSTATE `40001` (serialization_failure) and retries; on retry it sees the winner's row and skips.

### Part 5 — READ COMMITTED vs REPEATABLE READ
A reader session counts loans, a writer session inserts a loan and commits, the reader counts again. Under `READ COMMITTED` the count changes; under `REPEATABLE READ` the count is frozen for the transaction.

### Part 6 — deadlock then fixed lock order
Two rows `RACE-DL-A` and `RACE-DL-B`. Buggy order (T1 locks A then B; T2 locks B then A) deadlocks; one session aborts with SQLSTATE `40P01` (deadlock_detected). Fixed order (both lock A then B) completes without deadlock.

## Note

Drafted with AI assistance and will be tested and corrected before submission.
