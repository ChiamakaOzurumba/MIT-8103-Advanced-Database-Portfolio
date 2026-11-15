-- Sequential examples; run_portfolio.py executes and checks these cases.
BEGIN IMMEDIATE;
INSERT INTO enrolments(student_id,offering_id) VALUES(1,999);
COMMIT;
BEGIN IMMEDIATE;
DELETE FROM enrolments WHERE student_id=1 AND offering_id=999;
ROLLBACK;
-- Concurrent-session experiment (connections A and B):
-- A: BEGIN IMMEDIATE; INSERT INTO enrolments VALUES(2,999,CURRENT_TIMESTAMP);
-- B: SELECT COUNT(*) FROM enrolments WHERE offering_id=999; -- sees only committed row
-- B: BEGIN IMMEDIATE; -- SQLITE_BUSY while A holds writer lock (short timeout)
-- A: COMMIT;
-- B: BEGIN IMMEDIATE; then INSERT student 3 into offering 999 -> capacity trigger fails
-- B: ROLLBACK;
-- SQLite serialises writers at database level, not with row-level SELECT FOR UPDATE.
