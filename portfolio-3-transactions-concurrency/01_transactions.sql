-- Portfolio 3 - Transactions: commit, rollback, savepoint
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- Plain SQL transactions; DO blocks used ONLY for EXCEPTION handling.
-- No psql :variables inside DO blocks (use set_config/current_setting instead).
\set ON_ERROR_STOP off
\pset pager off

\echo '==== T1: COMMITTED transaction ===='
BEGIN;
INSERT INTO licence_holder(name, country, contact_email)
  VALUES ('TST3 Holder Committed','Nigeria','tst3c@ndma-test.ng');
COMMIT;
SELECT name AS committed_visible FROM licence_holder WHERE name = 'TST3 Holder Committed';

\echo '==== T2: ROLLED-BACK transaction ===='
BEGIN;
INSERT INTO licence_holder(name, country, contact_email)
  VALUES ('TST3 Holder Rolledback','Nigeria','tst3r@ndma-test.ng');
ROLLBACK;
SELECT count(*) AS rolledback_visible FROM licence_holder WHERE name = 'TST3 Holder Rolledback';

\echo '==== T3: SAVEPOINT recovery (DO block used only to raise+catch an error) ===='
BEGIN;
INSERT INTO licence_holder(name, country, contact_email)
  VALUES ('TST3 Before Savepoint','Nigeria','tst3b@ndma-test.ng');
SAVEPOINT sp_before_error;
DO $$
BEGIN
   RAISE EXCEPTION 'simulated error inside DO block';
EXCEPTION WHEN OTHERS THEN
   RAISE NOTICE 'T3: caught inside DO block - %', SQLERRM;
END $$;
ROLLBACK TO SAVEPOINT sp_before_error;
INSERT INTO licence_holder(name, country, contact_email)
  VALUES ('TST3 After Savepoint','Nigeria','tst3a@ndma-test.ng');
COMMIT;
SELECT name AS t3_survivors FROM licence_holder WHERE name LIKE 'TST3%' ORDER BY name;

\echo '==== T4: pass a value into a DO block with set_config/current_setting ===='
SELECT set_config('ndma.flag','on',false) AS set_value;
DO $$
DECLARE v text;
BEGIN
   v := current_setting('ndma.flag');
   RAISE NOTICE 'T4: ndma.flag read inside DO block = %', v;
END $$;

-- cleanup
DELETE FROM licence_holder WHERE name LIKE 'TST3%';
