PRAGMA foreign_keys = ON;
CREATE TABLE departments(department_id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
CREATE TABLE students(student_id INTEGER PRIMARY KEY, full_name TEXT NOT NULL,
 email TEXT NOT NULL UNIQUE, department_id INTEGER NOT NULL REFERENCES departments(department_id));
CREATE TABLE courses(course_id INTEGER PRIMARY KEY, code TEXT NOT NULL UNIQUE,
 title TEXT NOT NULL, credits INTEGER NOT NULL CHECK(credits BETWEEN 1 AND 6),
 department_id INTEGER NOT NULL REFERENCES departments(department_id));
CREATE TABLE offerings(offering_id INTEGER PRIMARY KEY, course_id INTEGER NOT NULL REFERENCES courses(course_id),
 term TEXT NOT NULL, capacity INTEGER NOT NULL CHECK(capacity > 0),
 UNIQUE(course_id,term));
CREATE TABLE enrolments(student_id INTEGER NOT NULL REFERENCES students(student_id),
 offering_id INTEGER NOT NULL REFERENCES offerings(offering_id),
 registered_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(student_id,offering_id));
CREATE TRIGGER check_capacity BEFORE INSERT ON enrolments
WHEN (SELECT COUNT(*) FROM enrolments WHERE offering_id=NEW.offering_id)
 >= (SELECT capacity FROM offerings WHERE offering_id=NEW.offering_id)
BEGIN SELECT RAISE(ABORT,'Course offering is full'); END;
