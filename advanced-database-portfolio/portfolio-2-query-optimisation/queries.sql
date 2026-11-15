-- Student's registered courses: join three tables.
SELECT c.code,c.title,o.term FROM enrolments e
JOIN offerings o ON e.offering_id=o.offering_id
JOIN courses c ON c.course_id=o.course_id WHERE e.student_id=1;
-- Class list, used for before/after benchmarking.
SELECT s.student_id,s.full_name FROM enrolments e
JOIN students s ON s.student_id=e.student_id WHERE e.offering_id=42;
-- Enrolment counts, including empty offerings.
SELECT o.offering_id,c.code,COUNT(e.student_id) AS registered
FROM offerings o JOIN courses c ON c.course_id=o.course_id
LEFT JOIN enrolments e ON e.offering_id=o.offering_id
GROUP BY o.offering_id,c.code ORDER BY o.offering_id LIMIT 10;
-- Students taking more than five courses (aggregation and HAVING).
SELECT student_id,COUNT(*) AS course_count FROM enrolments
GROUP BY student_id HAVING COUNT(*) > 5 ORDER BY student_id LIMIT 10;
-- EXPLAIN QUERY PLAN is run before and after this index in run_portfolio.py.
-- CREATE INDEX idx_enrolments_offering ON enrolments(offering_id);
