\set ON_ERROR_STOP on
BEGIN;
INSERT INTO students (name, email) VALUES ('Madina Ospanova', 'madina@example.com');
\set ON_ERROR_STOP off
INSERT INTO enrollments (course_id, student_id)
SELECT 'no-such-course', id FROM students WHERE email = 'madina@example.com';
-- Expected 25P02: this transaction is now aborted.
SELECT count(*) FROM students;
ROLLBACK;
\set ON_ERROR_STOP on
SELECT count(*) AS madina_after_rollback FROM students WHERE email = 'madina@example.com';
-- For successful transaction visibility, use two psql sessions as in README.
