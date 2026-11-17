-- Portfolio 1 - Constraint tests
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- 10 tests that must FAIL on the intended constraint + 1 control that must succeed.
-- Each test builds its own data so it does NOT depend on seed rows the bulk load might remove.
-- Output: RAISE NOTICE 'TESTnn <name>: PASS' when the constraint fires,
--         RAISE NOTICE 'TESTnn <name>: FAIL ...' when it does not.
\set ON_ERROR_STOP off

-- helper: clean any leftovers from a previous run
DELETE FROM users      WHERE email LIKE 'test%@ndma-test.ng';
DELETE FROM loan       WHERE requested_at < '2000-01-01';
DELETE FROM asset_copy WHERE barcode LIKE 'TST-%';
DELETE FROM media_asset WHERE title LIKE 'TST-%';
DELETE FROM archive_collection WHERE code LIKE 'TST-%';

-- =====================================================================
-- CONTROL TEST (must succeed)
-- =====================================================================
DO $$
DECLARE v_role INT;
BEGIN
    SELECT role_id INTO v_role FROM role WHERE name='ARCHIVIST' LIMIT 1;
    INSERT INTO users(role_id, full_name, email, password_hash)
      VALUES (v_role, 'Test Control User', 'test-control@ndma-test.ng',
              crypt('pw', gen_salt('bf')));
    RAISE NOTICE 'TEST00 CONTROL valid insert: PASS';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'TEST00 CONTROL valid insert: FAIL - %', SQLERRM;
END $$;

-- =====================================================================
-- TEST 01: NOT NULL on media_asset.title
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT;
BEGIN
    INSERT INTO archive_collection(name, code) VALUES ('TST01 Col','TST01-COL')
      RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST01 Fmt','VIDEO')
      RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium)
      VALUES (v_col, v_fmt, NULL, 'VIDEO');
    RAISE NOTICE 'TEST01 NOT NULL title: FAIL - insert succeeded unexpectedly';
EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'TEST01 NOT NULL title: PASS';
END $$;

-- =====================================================================
-- TEST 02: CHECK regex on archive_collection.code (no lowercase/space)
-- =====================================================================
DO $$
BEGIN
    INSERT INTO archive_collection(name, code) VALUES ('TST02 Col','bad code!');
    RAISE NOTICE 'TEST02 CHECK code regex: FAIL - insert succeeded unexpectedly';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST02 CHECK code regex: PASS';
END $$;

-- =====================================================================
-- TEST 03: UNIQUE on asset_copy.barcode
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT; v_loc INT; v_asset INT;
BEGIN
    INSERT INTO archive_collection(name, code) VALUES ('TST03 Col','TST03-COL') RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST03 Fmt','VIDEO') RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium) VALUES (v_col, v_fmt, 'TST03 Asset','VIDEO')
      RETURNING asset_id INTO v_asset;
    INSERT INTO storage_location(code, site) VALUES ('TST03-LOC','TST03 Site') RETURNING location_id INTO v_loc;
    INSERT INTO asset_copy(asset_id, location_id, kind, barcode) VALUES (v_asset, v_loc, 'DIGITAL','TST03-BC-001');
    INSERT INTO asset_copy(asset_id, location_id, kind, barcode) VALUES (v_asset, v_loc, 'PHYSICAL','TST03-BC-001');
    RAISE NOTICE 'TEST03 UNIQUE barcode: FAIL - duplicate accepted unexpectedly';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'TEST03 UNIQUE barcode: PASS';
END $$;

-- =====================================================================
-- TEST 04: FK violation on loan.user_id
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT; v_loc INT; v_asset INT; v_copy INT;
BEGIN
    INSERT INTO archive_collection(name, code) VALUES ('TST04 Col','TST04-COL') RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST04 Fmt','VIDEO') RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium) VALUES (v_col, v_fmt, 'TST04 Asset','VIDEO')
      RETURNING asset_id INTO v_asset;
    INSERT INTO storage_location(code, site) VALUES ('TST04-LOC','TST04 Site') RETURNING location_id INTO v_loc;
    INSERT INTO asset_copy(asset_id, location_id, kind, barcode) VALUES (v_asset, v_loc, 'DIGITAL','TST04-BC')
      RETURNING copy_id INTO v_copy;
    INSERT INTO loan(asset_copy_id, user_id, status, start_at, end_at)
      VALUES (v_copy, 999999, 'REQUESTED', now(), now() + interval '1 day');
    RAISE NOTICE 'TEST04 FK loan.user_id: FAIL - orphan accepted unexpectedly';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'TEST04 FK loan.user_id: PASS';
END $$;

-- =====================================================================
-- TEST 05: CHECK licence.end_date >= start_date
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT; v_asset INT; v_holder INT;
BEGIN
    INSERT INTO archive_collection(name, code) VALUES ('TST05 Col','TST05-COL') RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST05 Fmt','VIDEO') RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium) VALUES (v_col, v_fmt, 'TST05 Asset','VIDEO')
      RETURNING asset_id INTO v_asset;
    INSERT INTO licence_holder(name) VALUES ('TST05 Holder') RETURNING holder_id INTO v_holder;
    INSERT INTO licence(asset_id, holder_id, licence_type, start_date, end_date)
      VALUES (v_asset, v_holder, 'NON_EXCLUSIVE', DATE '2026-01-01', DATE '2025-12-31');
    RAISE NOTICE 'TEST05 CHECK licence dates: FAIL - bad range accepted unexpectedly';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST05 CHECK licence dates: PASS';
END $$;

-- =====================================================================
-- TEST 06: Trigger - asset ARCHIVED without checksum
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT;
BEGIN
    INSERT INTO archive_collection(name, code) VALUES ('TST06 Col','TST06-COL') RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST06 Fmt','VIDEO') RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium, status)
      VALUES (v_col, v_fmt, 'TST06 Asset','VIDEO','ARCHIVED');
    RAISE NOTICE 'TEST06 TRIGGER archived-no-checksum: FAIL - insert succeeded unexpectedly';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'TEST06 TRIGGER archived-no-checksum: PASS - %', SQLERRM;
END $$;

-- =====================================================================
-- TEST 07: CHECK media_asset.duration_sec > 0
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT;
BEGIN
    INSERT INTO archive_collection(name, code) VALUES ('TST07 Col','TST07-COL') RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST07 Fmt','VIDEO') RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium, duration_sec)
      VALUES (v_col, v_fmt, 'TST07 Asset','VIDEO', -5);
    RAISE NOTICE 'TEST07 CHECK duration_sec > 0: FAIL - negative accepted unexpectedly';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST07 CHECK duration_sec > 0: PASS';
END $$;

-- =====================================================================
-- TEST 08: CHECK loan.end_at > start_at
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT; v_loc INT; v_asset INT; v_copy INT; v_user INT; v_role INT;
BEGIN
    SELECT role_id INTO v_role FROM role WHERE name='RESEARCHER' LIMIT 1;
    INSERT INTO users(role_id, full_name, email, password_hash)
      VALUES (v_role,'TST08 User','test08@ndma-test.ng', crypt('pw', gen_salt('bf')))
      RETURNING user_id INTO v_user;
    INSERT INTO archive_collection(name, code) VALUES ('TST08 Col','TST08-COL') RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST08 Fmt','VIDEO') RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium) VALUES (v_col, v_fmt, 'TST08 Asset','VIDEO')
      RETURNING asset_id INTO v_asset;
    INSERT INTO storage_location(code, site) VALUES ('TST08-LOC','TST08 Site') RETURNING location_id INTO v_loc;
    INSERT INTO asset_copy(asset_id, location_id, kind, barcode) VALUES (v_asset, v_loc, 'DIGITAL','TST08-BC')
      RETURNING copy_id INTO v_copy;
    INSERT INTO loan(asset_copy_id, user_id, status, start_at, end_at)
      VALUES (v_copy, v_user, 'REQUESTED', '2026-06-01 10:00+01', '2026-06-01 10:00+01');
    RAISE NOTICE 'TEST08 CHECK loan end_at > start_at: FAIL - equal dates accepted unexpectedly';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST08 CHECK loan end_at > start_at: PASS';
END $$;

-- =====================================================================
-- TEST 09: CHECK users.email regex
-- =====================================================================
DO $$
DECLARE v_role INT;
BEGIN
    SELECT role_id INTO v_role FROM role WHERE name='ARCHIVIST' LIMIT 1;
    INSERT INTO users(role_id, full_name, email, password_hash)
      VALUES (v_role,'TST09 User','not-an-email', crypt('pw', gen_salt('bf')));
    RAISE NOTICE 'TEST09 CHECK email regex: FAIL - bad email accepted unexpectedly';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST09 CHECK email regex: PASS';
END $$;

-- =====================================================================
-- TEST 10: Partial UNIQUE index ux_loan_active (two active loans same copy)
-- =====================================================================
DO $$
DECLARE v_col INT; v_fmt INT; v_loc INT; v_asset INT; v_copy INT; v_u1 INT; v_u2 INT; v_role INT;
BEGIN
    SELECT role_id INTO v_role FROM role WHERE name='RESEARCHER' LIMIT 1;
    INSERT INTO users(role_id, full_name, email, password_hash)
      VALUES (v_role,'TST10 A','test10a@ndma-test.ng', crypt('pw', gen_salt('bf'))) RETURNING user_id INTO v_u1;
    INSERT INTO users(role_id, full_name, email, password_hash)
      VALUES (v_role,'TST10 B','test10b@ndma-test.ng', crypt('pw', gen_salt('bf'))) RETURNING user_id INTO v_u2;
    INSERT INTO archive_collection(name, code) VALUES ('TST10 Col','TST10-COL') RETURNING collection_id INTO v_col;
    INSERT INTO asset_format(name, medium) VALUES ('TST10 Fmt','VIDEO') RETURNING format_id INTO v_fmt;
    INSERT INTO media_asset(collection_id, format_id, title, medium) VALUES (v_col, v_fmt, 'TST10 Asset','VIDEO')
      RETURNING asset_id INTO v_asset;
    INSERT INTO storage_location(code, site) VALUES ('TST10-LOC','TST10 Site') RETURNING location_id INTO v_loc;
    INSERT INTO asset_copy(asset_id, location_id, kind, barcode) VALUES (v_asset, v_loc, 'DIGITAL','TST10-BC')
      RETURNING copy_id INTO v_copy;
    INSERT INTO loan(asset_copy_id, user_id, status, start_at, end_at)
      VALUES (v_copy, v_u1, 'APPROVED', now(), now() + interval '1 day');
    INSERT INTO loan(asset_copy_id, user_id, status, start_at, end_at)
      VALUES (v_copy, v_u2, 'ACTIVE', now() + interval '2 days', now() + interval '3 days');
    RAISE NOTICE 'TEST10 PARTIAL UNIQUE ux_loan_active: FAIL - two active loans accepted unexpectedly';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'TEST10 PARTIAL UNIQUE ux_loan_active: PASS';
END $$;

-- cleanup test artefacts
DELETE FROM users      WHERE email LIKE 'test%@ndma-test.ng';
DELETE FROM loan       WHERE asset_copy_id IN (SELECT copy_id FROM asset_copy WHERE barcode LIKE 'TST-%');
DELETE FROM asset_copy WHERE barcode LIKE 'TST-%';
DELETE FROM media_asset WHERE title LIKE 'TST-%';
DELETE FROM archive_collection WHERE code LIKE 'TST-%';
DELETE FROM storage_location WHERE code LIKE 'TST-%';
DELETE FROM asset_format WHERE name LIKE 'TST%';
DELETE FROM licence_holder WHERE name LIKE 'TST%';

\echo 'Done. Expected: 10 PASS + 1 PASS (control).'
