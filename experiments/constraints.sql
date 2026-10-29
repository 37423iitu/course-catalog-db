-- These ten errors are intentional. Each command runs outside a transaction.
\set ON_ERROR_STOP off
\set VERBOSITY verbose
INSERT INTO courses (id, title, description, credits) VALUES ('x-test', NULL, 'Test', 3);
INSERT INTO courses (id, title, description, credits) VALUES ('x-test', 'Test', 'Test', 0);
UPDATE courses SET likes = -1 WHERE id = 'api-design';
INSERT INTO students (name, email) VALUES ('A', 'a@example.com');
INSERT INTO students (name, email) VALUES ('Dup Student', 'aigerim@example.com');
INSERT INTO courses (id, title, description, credits) VALUES ('api-design', 'x', 'y', 1);
INSERT INTO enrollments (course_id, student_id) VALUES ('modern-frontend', 1);
INSERT INTO enrollments (course_id, student_id) VALUES ('no-such-course', 1);
INSERT INTO enrollments (course_id, student_id) VALUES ('web-security', 999);
DELETE FROM courses WHERE id = 'modern-frontend';
\set ON_ERROR_STOP on
\set VERBOSITY default
BEGIN;
SELECT count(*) AS before_delete FROM enrollments;
DELETE FROM students WHERE email = 'daniyar@example.com';
SELECT count(*) AS after_cascade FROM enrollments;
ROLLBACK;
SELECT count(*) AS after_rollback FROM enrollments;
