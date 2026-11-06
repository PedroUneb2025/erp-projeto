#!/bin/sh
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=app_pass="$APP_DB_PASSWORD" --set=bi_pass="$BI_DB_PASSWORD" --set=mb_pass="$METABASE_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE erp_app LOGIN PASSWORD %L', :'app_pass') \gexec
SELECT format('CREATE ROLE erp_bi LOGIN PASSWORD %L', :'bi_pass') \gexec
SELECT format('CREATE ROLE metabase LOGIN PASSWORD %L', :'mb_pass') \gexec
CREATE DATABASE metabase OWNER metabase;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL
