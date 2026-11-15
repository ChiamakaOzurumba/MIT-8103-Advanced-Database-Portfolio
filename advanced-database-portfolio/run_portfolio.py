"""Reproduce the portfolio with Python 3, using only its standard library.
Run in a disposable copy: replaces only generated databases/evidence in this folder.
"""
from pathlib import Path
import sqlite3, json, time, statistics, platform, dbm.dumb
from datetime import datetime, timezone
ROOT=Path(__file__).resolve().parent
E=ROOT/'evidence'; E.mkdir(exist_ok=True)
D=ROOT/'generated'; D.mkdir(exist_ok=True)
DB=D/'campus.sqlite'
for suffix in ('','-wal','-shm'):
    f=Path(str(DB)+suffix)
    if f.exists(): f.unlink()
def connect():
    c=sqlite3.connect(DB,timeout=0.1,isolation_level=None)
    c.execute('PRAGMA foreign_keys=ON')
    return c
def save(name,lines): (E/name).write_text('\n'.join(map(str,lines))+'\n')
c=connect(); c.execute('PRAGMA journal_mode=WAL')
c.executescript((ROOT/'portfolio-1-database-design/schema.sql').read_text())
c.execute('BEGIN')
c.execute("INSERT INTO departments VALUES(1,'Information Technology')")
c.executemany('INSERT INTO students VALUES(?,?,?,1)',[(i,f'Synthetic Student {i:05d}',f'student{i}@example.invalid') for i in range(1,10001)])
c.executemany('INSERT INTO courses VALUES(?,?,?,?,1)',[(i,f'SIM{i:03d}',f'Simulated course {i}',3) for i in range(1,101)])
c.executemany("INSERT INTO offerings VALUES(?,?,'2026-T1',2000)",[(i,i) for i in range(1,101)])
# Each of 10,000 students receives 6 distinct offerings: 60,000 enrolments.
c.executemany('INSERT INTO enrolments(student_id,offering_id) VALUES(?,?)',[(s,((s*7+k*13)%100)+1) for s in range(1,10001) for k in range(6)])
c.execute("INSERT INTO offerings VALUES(999,1,'2027-T1',2)")
c.execute('COMMIT')
checks=['Actual run: '+datetime.now(timezone.utc).isoformat(), 'Python '+platform.python_version(), 'SQLite '+sqlite3.sqlite_version,
        'Synthetic data: 10,000 students; 100 courses; 101 offerings; 60,000 initial enrolments.']
checks.append('foreign_key_check: '+str(c.execute('PRAGMA foreign_key_check').fetchall()))
checks.append('integrity_check: '+str(c.execute('PRAGMA integrity_check').fetchone()[0]))
def rejected(label,sql):
    try: c.execute(sql)
    except sqlite3.IntegrityError as ex: checks.append(label+': PASS - '+str(ex))
    else: raise AssertionError(label+' was not rejected')
rejected('Duplicate registration',"INSERT INTO enrolments(student_id,offering_id) SELECT student_id,offering_id FROM enrolments LIMIT 1")
rejected('Orphan registration',"INSERT INTO enrolments(student_id,offering_id) VALUES(10001,999)")
rejected('Invalid credits',"INSERT INTO courses VALUES(101,'INVALID','Invalid',0,1)")
rejected('Duplicate email',"INSERT INTO students VALUES(10001,'Duplicate','student1@example.invalid',1)")
save('design-tests.txt',checks)
query='SELECT s.student_id,s.full_name FROM enrolments e JOIN students s ON s.student_id=e.student_id WHERE e.offering_id=42'
def bench():
    for _ in range(5): c.execute(query).fetchall()
    vals=[]
    for _ in range(30):
        t=time.perf_counter(); rows=c.execute(query).fetchall(); vals.append((time.perf_counter()-t)*1000)
    return statistics.median(vals),rows,vals
before_plan=c.execute('EXPLAIN QUERY PLAN '+query).fetchall()
before,rows_b,samples_b=bench()
c.execute('CREATE INDEX idx_enrolments_offering ON enrolments(offering_id)')
c.execute('ANALYZE')
after_plan=c.execute('EXPLAIN QUERY PLAN '+query).fetchall()
after,rows_a,samples_a=bench()
assert sorted(rows_b)==sorted(rows_a)
metrics={'before_median_ms':before,'after_median_ms':after,'ratio':before/after,'returned_rows':len(rows_a),'before_plan':before_plan,'after_plan':after_plan,'before_samples_ms':samples_b,'after_samples_ms':samples_a}
(E/'performance.json').write_text(json.dumps(metrics,indent=2))
save('query-plans.txt',['BEFORE',*before_plan,'AFTER',*after_plan,f'Median milliseconds: before={before:.4f}; after={after:.4f}; ratio={before/after:.2f}x',f'Result equality: PASS ({len(rows_a)} rows)', '30 timed executions per phase after 5 warm-ups; same connection and dataset. Full fetch included. Before phase always first; warm-cache local microbenchmark, not a production prediction. Index consumes storage and adds insert/update cost.'])
queries=[('Student 1 courses',"SELECT c.code,c.title,o.term FROM enrolments e JOIN offerings o ON e.offering_id=o.offering_id JOIN courses c ON c.course_id=o.course_id WHERE e.student_id=1"),('Class 42 (first 10 rows)',query+' LIMIT 10'),('Enrolment counts',"SELECT o.offering_id,c.code,COUNT(e.student_id) FROM offerings o JOIN courses c ON c.course_id=o.course_id LEFT JOIN enrolments e ON e.offering_id=o.offering_id GROUP BY o.offering_id,c.code ORDER BY o.offering_id LIMIT 10"),('More than five courses',"SELECT student_id,COUNT(*) FROM enrolments GROUP BY student_id HAVING COUNT(*)>5 ORDER BY student_id LIMIT 10")]
results=[]
for label,q in queries: results += [label,q,str(c.execute(q).fetchall())]
save('query-results.txt',results)
a=c; b=connect(); log=[]
a.execute('BEGIN IMMEDIATE'); a.execute('INSERT INTO enrolments(student_id,offering_id) VALUES(1,999)'); a.execute('COMMIT')
assert b.execute('SELECT COUNT(*) FROM enrolments WHERE offering_id=999').fetchone()[0]==1
log.append('COMMIT: student 1 registration is visible to connection B; count=1. PASS')
a.execute('BEGIN IMMEDIATE'); a.execute('DELETE FROM enrolments WHERE student_id=1 AND offering_id=999'); a.execute('ROLLBACK')
assert a.execute('SELECT COUNT(*) FROM enrolments WHERE offering_id=999').fetchone()[0]==1
log.append('ROLLBACK: deletion reversed; student 1 remains registered. PASS')
a.execute('BEGIN IMMEDIATE'); a.execute('INSERT INTO enrolments(student_id,offering_id) VALUES(2,999)')
assert a.execute('SELECT COUNT(*) FROM enrolments WHERE offering_id=999').fetchone()[0]==2
assert b.execute('SELECT COUNT(*) FROM enrolments WHERE offering_id=999').fetchone()[0]==1
log.append('ISOLATION: A sees its uncommitted count=2; B sees committed count=1. PASS')
try: b.execute('BEGIN IMMEDIATE')
except sqlite3.OperationalError as ex:
    assert 'locked' in str(ex); log.append('CONCURRENCY: B cannot obtain writer lock while A is active: '+str(ex)+'. PASS')
else: raise AssertionError('Expected writer contention')
a.execute('COMMIT'); b.execute('BEGIN IMMEDIATE')
try: b.execute('INSERT INTO enrolments(student_id,offering_id) VALUES(3,999)')
except sqlite3.IntegrityError as ex: log.append('CAPACITY: after A commits, B retries and is rejected: '+str(ex)+'. PASS'); b.execute('ROLLBACK')
else: raise AssertionError('Expected capacity rejection')
assert a.execute('SELECT COUNT(*) FROM enrolments WHERE offering_id=999').fetchone()[0]==2
log.append('Final offering 999 enrolments=2, capacity=2: no oversubscription. PASS')
log.append('Two real independent connections with overlapping transactions; deterministic interleaving in one Python process, not a multi-machine load test.')
log.append('WAL allows a reader during a writer transaction; writers remain serialised. A production client should handle lock errors with bounded retries and recheck capacity.')
save('transactions.txt',log); b.close(); a.close()
key='student:1:preferences'; obj={'student_id':1,'language':'en-GB','notifications':['email'],'accessibility':{'large_text':False}}
kv=D/'student-preferences'; nlog=[]
with dbm.dumb.open(str(kv),'n') as d:
    d[key]=json.dumps(obj); assert json.loads(d[key])==obj; nlog.append('CREATE and READ: '+d[key].decode())
    obj['notifications'].append('sms'); d[key]=json.dumps(obj); nlog.append('UPDATE: '+d[key].decode())
with dbm.dumb.open(str(kv),'w') as d:
    assert json.loads(d[key])['notifications']==['email','sms']; nlog.append('PERSISTENCE: updated value survived close/reopen. PASS')
    d['student:2:preferences']=json.dumps({'student_id':2,'language':'ha'}); del d['student:2:preferences']; assert 'student:2:preferences' not in d; nlog.append('DELETE: second test key removed. PASS')
    nlog.append('Final key count='+str(len(d)))
save('nosql.txt',nlog)
(ROOT/'portfolio-4-nosql/profile-example.json').write_text(json.dumps({'key':key,'value':obj},indent=2))
save('verification-summary.txt',['ALL ASSERTIONS PASSED','Design constraints, query result equivalence, commit, rollback, isolation, lock contention, capacity limit and key-value persistence verified.','Run time (UTC): '+datetime.now(timezone.utc).isoformat()])
print('\n'.join(checks));print('\n'.join(log));print(f'Query median before {before:.4f} ms; after {after:.4f} ms; ratio {before/after:.2f}x');print('ALL ASSERTIONS PASSED')
