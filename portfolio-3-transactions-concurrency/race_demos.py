#!/usr/bin/env python3
"""Portfolio 3 - Race condition demos.
Student: Chiamaka Ozurumba (2026/A/MIT/1005)

Two real psycopg2 sessions driven by Python threads. No pg_sleep, no hand pasting.
Parts (output to race_demos_output.log):
  1. The bug (double lending of the same asset copy)
  2. UNIQUE constraint fix
  3. OUR TECHNIQUE: EXCLUSION CONSTRAINT with btree_gist on tstzrange overlap
  4. SERIALIZABLE retry on SQLSTATE 40001
  5. READ COMMITTED vs REPEATABLE READ snapshot difference
  6. Deadlock then fixed lock order (two rows)
Data is reset between parts.
"""
import logging, threading, datetime as dt
import psycopg2

DSN = "dbname=mediaarchive host=/var/run/postgresql"
LOG_PATH = "race_demos_output.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(threadName)s %(message)s",
    handlers=[logging.FileHandler(LOG_PATH, mode="w"), logging.StreamHandler()],
)
log = logging.getLogger("race")


def connect(isolation=None):
    conn = psycopg2.connect(DSN)
    conn.autocommit = False
    if isolation:
        conn.set_session(isolation_level=isolation)
    return conn


def exec_one(sql, args=None, conn=None):
    own = conn is None
    if own:
        conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args or ())
            try:
                return cur.fetchone()
            except psycopg2.ProgrammingError:
                return None
        if own:
            conn.commit()
    finally:
        if own:
            conn.close()


def setup_fixtures():
    """Create dedicated fixtures so the race never depends on seed rows."""
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM loan WHERE asset_copy_id IN "
                        "(SELECT copy_id FROM asset_copy WHERE barcode LIKE 'RACE-%')")
            cur.execute("DELETE FROM asset_copy WHERE barcode LIKE 'RACE-%'")
            cur.execute("DELETE FROM media_asset WHERE checksum = 'race-sha-aaaaaaaaaaaaaaaaaaaa'")   # makes the demo re-runnable
            cur.execute("""INSERT INTO archive_collection(name, code)
                           VALUES ('Race Fixture','RACE-FIX')
                           ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name
                           RETURNING collection_id""")
            col = cur.fetchone()[0]
            cur.execute("""INSERT INTO asset_format(name, medium)
                           VALUES ('Race Fmt','VIDEO')
                           ON CONFLICT (name) DO UPDATE SET medium=EXCLUDED.medium
                           RETURNING format_id""")
            fmt = cur.fetchone()[0]
            cur.execute("""INSERT INTO media_asset(collection_id, format_id, title, medium, status, checksum)
                           VALUES (%s,%s,'Race Asset','VIDEO','ARCHIVED','race-sha-aaaaaaaaaaaaaaaaaaaa')
                           RETURNING asset_id""", (col, fmt))
            asset = cur.fetchone()[0]
            cur.execute("""INSERT INTO storage_location(code, site)
                           VALUES ('RACE-LOC','Race Site')
                           ON CONFLICT (code) DO UPDATE SET site=EXCLUDED.site
                           RETURNING location_id""")
            loc = cur.fetchone()[0]
            cur.execute("""INSERT INTO asset_copy(asset_id, location_id, kind, barcode, is_available)
                           VALUES (%s,%s,'DIGITAL','RACE-COPY',true)
                           ON CONFLICT (barcode) DO UPDATE SET is_available=true
                           RETURNING copy_id""", (asset, loc))
            copy_id = cur.fetchone()[0]
            cur.execute("""INSERT INTO users(role_id, full_name, email, password_hash)
                           VALUES ((SELECT role_id FROM role WHERE name='RESEARCHER' LIMIT 1),
                                   'Race User','race.user@ndma-test.ng','race-hash-01234567890123456789')
                           ON CONFLICT DO NOTHING""")
            cur.execute("SELECT user_id FROM users WHERE email='race.user@ndma-test.ng'")
            user_id = cur.fetchone()[0]
            for tag in ('A', 'B'):
                cur.execute("""INSERT INTO asset_copy(asset_id, location_id, kind, barcode, is_available)
                               VALUES (%s,%s,'PHYSICAL','RACE-DL-'||%s,true)
                               ON CONFLICT (barcode) DO UPDATE SET is_available=true
                               RETURNING copy_id""", (asset, loc, tag))
        conn.commit()
        return {'copy_id': copy_id, 'user_id': user_id, 'asset_id': asset}
    finally:
        conn.close()


def reset_loan_constraints():
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute("ALTER TABLE loan DROP CONSTRAINT IF EXISTS loan_no_overlap;")
            cur.execute("DROP INDEX IF EXISTS ux_loan_active;")
            cur.execute("DROP INDEX IF EXISTS ux_loan_active_race;")
        conn.commit()
    finally:
        conn.close()


def clear_loans(fixture):
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM loan WHERE asset_copy_id = %s", (fixture['copy_id'],))
        conn.commit()
    finally:
        conn.close()


def add_unique_fix():
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute("""CREATE UNIQUE INDEX ux_loan_active_race
                           ON loan(asset_copy_id) WHERE status IN ('APPROVED','ACTIVE')""")
        conn.commit()
    finally:
        conn.close()


def add_exclusion_fix():
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute("""ALTER TABLE loan ADD CONSTRAINT loan_no_overlap
                           EXCLUDE USING gist (
                              asset_copy_id WITH =,
                              tstzrange(start_at, end_at) WITH &&
                           )""")
        conn.commit()
    finally:
        conn.close()


def lend_once(fixture, start_at, end_at, label, isolation=None):
    conn = connect(isolation)
    try:
        with conn.cursor() as cur:
            cur.execute("""INSERT INTO loan(asset_copy_id, user_id, status, start_at, end_at)
                           VALUES (%s,%s,'APPROVED',%s,%s)""",
                         (fixture['copy_id'], fixture['user_id'], start_at, end_at))
        conn.commit()
        return (True, "inserted")
    except psycopg2.Error as e:
        conn.rollback()
        return (False, "%s %s" % (e.pgcode, (e.pgerror or str(e)).strip().splitlines()[0]))
    finally:
        conn.close()


def run_lending_race(fixture, start_at, end_at, part, isolation=None):
    barrier = threading.Barrier(2)
    results = {}

    def worker(name):
        try:
            barrier.wait()
        except threading.BrokenBarrierError:
            pass
        ok, detail = lend_once(fixture, start_at, end_at, name, isolation)
        results[name] = (ok, detail)
        log.info("%s PART%d %s: ok=%s detail=%s", name, part, name, ok, detail)

    t1 = threading.Thread(target=worker, args=("T1",), name="T1")
    t2 = threading.Thread(target=worker, args=("T2",), name="T2")
    t1.start(); t2.start()
    t1.join(); t2.join()
    both_ok = results.get("T1",(False,))[0] and results.get("T2",(False,))[0]
    log.info("PART%d result: T1=%s T2=%s both_succeeded=%s",
             part, results.get("T1"), results.get("T2"), both_ok)
    return results


def run_serializable_race(fixture, start_at, end_at, part):
    barrier = threading.Barrier(2)
    results = {}

    def worker(name):
        for attempt in range(3):
            conn = connect('SERIALIZABLE')
            try:
                with conn.cursor() as cur:
                    if attempt == 0:   # only the first attempt waits for the other thread; a retry must not wait
                        try:
                            barrier.wait(timeout=10)
                        except threading.BrokenBarrierError:
                            pass
                    cur.execute("SELECT 1 FROM loan WHERE asset_copy_id=%s AND status='APPROVED'",
                                (fixture['copy_id'],))
                    if cur.fetchone():
                        conn.rollback()
                        results[name] = (False, "skipped: APPROVED loan already exists")
                        log.info("%s PART%d %s: skipped on attempt %d", name, part, name, attempt + 1)
                        return
                    cur.execute("""INSERT INTO loan(asset_copy_id, user_id, status, start_at, end_at)
                                   VALUES (%s,%s,'APPROVED',%s,%s)""",
                                 (fixture['copy_id'], fixture['user_id'], start_at, end_at))
                conn.commit()
                results[name] = (True, "inserted attempt %d" % (attempt + 1))
                log.info("%s PART%d %s: inserted on attempt %d", name, part, name, attempt + 1)
                return
            except psycopg2.Error as e:
                conn.rollback()
                if e.pgcode == '40001':
                    log.info("%s PART%d %s: 40001 on attempt %d, retrying", name, part, name, attempt + 1)
                    continue
                results[name] = (False, "%s %s" % (e.pgcode, str(e).strip().splitlines()[0]))
                log.info("%s PART%d %s: error %s", name, part, name, results[name])
                return
            finally:
                conn.close()
        results[name] = (False, "exhausted retries")
        log.info("%s PART%d %s: exhausted retries", name, part, name)

    t1 = threading.Thread(target=worker, args=("T1",), name="T1")
    t2 = threading.Thread(target=worker, args=("T2",), name="T2")
    t1.start(); t2.start()
    t1.join(); t2.join()
    log.info("PART%d result: T1=%s T2=%s", part, results.get("T1"), results.get("T2"))


def run_snapshot_demo(fixture, part):
    """Show REPEATABLE READ keeps a stable snapshot; READ COMMITTED sees new commits."""
    def demo(isolation, label):
        reader = connect(isolation)
        writer = connect()
        try:
            with reader.cursor() as rc:
                rc.execute("SELECT count(*) FROM loan WHERE asset_copy_id=%s", (fixture['copy_id'],))
                before = rc.fetchone()[0]
                with writer.cursor() as wc:
                    wc.execute("""INSERT INTO loan(asset_copy_id, user_id, status, start_at, end_at)
                                  VALUES (%s,%s,'REQUESTED',now(),now()+interval '1 day')""",
                               (fixture['copy_id'], fixture['user_id']))
                writer.commit()
                rc.execute("SELECT count(*) FROM loan WHERE asset_copy_id=%s", (fixture['copy_id'],))
                after = rc.fetchone()[0]
                reader.commit()
                same = (before == after)
                log.info("PART%d %s: before=%s after=%s same_snapshot=%s", part, label, before, after, same)
                return (before, after, same)
        finally:
            reader.close(); writer.close()
    clear_loans(fixture)
    rc = demo('READ COMMITTED', 'READ_COMMITTED')
    clear_loans(fixture)
    rr = demo('REPEATABLE READ', 'REPEATABLE_READ')
    log.info("PART%d summary: READ_COMMITTED same=%s ; REPEATABLE_READ same=%s",
             part, rc[2], rr[2])


def run_deadlock_demo(fixture, part):
    """Two rows RACE-DL-A and RACE-DL-B. Buggy order deadlocks; fixed order does not."""
    def lock_two(first, second, label, barrier):
        conn = connect()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT copy_id FROM asset_copy WHERE barcode=%s FOR UPDATE", (first,))
                try:
                    barrier.wait(timeout=2)   # in the fixed order the second thread is blocked on row A, so do not wait forever
                except threading.BrokenBarrierError:
                    pass
                cur.execute("SELECT copy_id FROM asset_copy WHERE barcode=%s FOR UPDATE", (second,))
            conn.commit()
            return (True, "locked %s then %s" % (first, second))
        except psycopg2.Error as e:
            conn.rollback()
            return (False, "%s %s" % (e.pgcode, str(e).strip().splitlines()[0]))
        finally:
            conn.close()

    def run_once(order, sub):
        barrier = threading.Barrier(2)
        res = {}
        def w(name, first, second):
            res[name] = lock_two(first, second, name, barrier)
            log.info("%s PART%d-%s %s: %s", name, part, sub, name, res[name])
        if order == 'buggy':
            t1 = threading.Thread(target=w, args=("T1", 'RACE-DL-A', 'RACE-DL-B'), name="T1")
            t2 = threading.Thread(target=w, args=("T2", 'RACE-DL-B', 'RACE-DL-A'), name="T2")
        else:
            t1 = threading.Thread(target=w, args=("T1", 'RACE-DL-A', 'RACE-DL-B'), name="T1")
            t2 = threading.Thread(target=w, args=("T2", 'RACE-DL-A', 'RACE-DL-B'), name="T2")
        t1.start(); t2.start(); t1.join(); t2.join()
        log.info("PART%d-%s result: T1=%s T2=%s", part, sub, res.get("T1"), res.get("T2"))

    run_once('buggy', 'buggy')
    run_once('fixed', 'fixed')


def main():
    log.info("=== race_demos START (student Chiamaka Ozurumba 2026/A/MIT/1005) ===")
    fixture = setup_fixtures()
    reset_loan_constraints()
    now = dt.datetime.now(dt.timezone.utc)
    start_at = now + dt.timedelta(days=1)
    end_at = now + dt.timedelta(days=2)

    # Part 1: the bug (no overlap constraint) -> both threads succeed
    log.info("--- PART 1: the bug (double lending) ---")
    clear_loans(fixture)
    run_lending_race(fixture, start_at, end_at, 1)

    # Part 2: UNIQUE fix
    log.info("--- PART 2: UNIQUE constraint fix ---")
    clear_loans(fixture)
    add_unique_fix()
    run_lending_race(fixture, start_at, end_at, 2)
    reset_loan_constraints()

    # Part 3: OUR TECHNIQUE - EXCLUSION with btree_gist
    log.info("--- PART 3: EXCLUSION CONSTRAINT fix (btree_gist) ---")
    clear_loans(fixture)
    add_exclusion_fix()
    run_lending_race(fixture, start_at, end_at, 3)
    reset_loan_constraints()

    # Part 4: SERIALIZABLE retry on 40001
    log.info("--- PART 4: SERIALIZABLE retry on SQLSTATE 40001 ---")
    clear_loans(fixture)
    run_serializable_race(fixture, start_at, end_at, 4)
    reset_loan_constraints()

    # Part 5: READ COMMITTED vs REPEATABLE READ
    log.info("--- PART 5: READ COMMITTED vs REPEATABLE READ ---")
    clear_loans(fixture)
    run_snapshot_demo(fixture, 5)
    clear_loans(fixture)

    # Part 6: deadlock then fixed lock order
    log.info("--- PART 6: deadlock then fixed lock order ---")
    run_deadlock_demo(fixture, 6)

    log.info("=== race_demos END ===")


if __name__ == "__main__":
    main()
