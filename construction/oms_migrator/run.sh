#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is not set. Provide it via .env or environment variables." >&2
  exit 1
fi

echo "Running OMS data migration against: ${DATABASE_URL}"

# Print server version
psql "${DATABASE_URL}" -c "select version();" | cat

# Execute migration SQL (mounted at /work/oms_data_migration.sql)
psql "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f /work/oms_data_migration.sql | cat

echo "Migration finished."



