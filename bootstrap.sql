\set ON_ERROR_STOP on
\getenv app_password CATALOG_DB_PASSWORD
-- Used by start-local.ps1 on its private cluster only.
SELECT format('CREATE ROLE catalog_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='catalog_app') \gexec
SELECT format('CREATE DATABASE %I OWNER catalog_app', db)
FROM (VALUES ('course_catalog'), ('idx_demo'), ('norm_demo')) AS names(db)
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname=db) \gexec
