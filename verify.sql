\set ON_ERROR_STOP on
DO $$
BEGIN
 IF (SELECT count(*) FROM courses) <> 6 OR
    (SELECT count(*) FROM students) <> 3 OR
    (SELECT count(*) FROM enrollments) <> 6 THEN
   RAISE EXCEPTION 'Expected 6 courses, 3 students, 6 enrollments';
 END IF;
 IF (SELECT sum(likes) FROM courses) <> 122 THEN RAISE EXCEPTION 'Likes changed'; END IF;
 IF EXISTS (SELECT 1 FROM students WHERE email = 'madina@example.com') THEN
   RAISE EXCEPTION 'Transaction test left data';
 END IF;
END $$;
SELECT 'PASS: 6 courses, 3 students, 6 enrollments, 122 likes' AS verification;
SELECT c.id, count(e.id) AS enrolled FROM courses c
LEFT JOIN enrollments e ON e.course_id=c.id GROUP BY c.id ORDER BY enrolled DESC, c.id;
\d courses
\d students
\d enrollments
