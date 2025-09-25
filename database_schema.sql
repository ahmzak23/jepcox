-- Base database bootstrap for enterprise multi-service setup
-- Purpose: create extensions and per-service schemas only

-- Create database (run separately if needed):
   CREATE DATABASE om_db;
--   \c om_db;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Service schemas (namespaces)
-- CREATE SCHEMA IF NOT EXISTS hes AUTHORIZATION CURRENT_USER;
-- CREATE SCHEMA IF NOT EXISTS scada AUTHORIZATION CURRENT_USER;

-- Optional: default search path
-- ALTER DATABASE om_db SET search_path = public, hes, scada;

-- Bootstrap check tables (non-critical)
CREATE TABLE IF NOT EXISTS hes._bootstrap_check (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS scada._bootstrap_check (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- No business tables here. Apply service schemas next:
--   psql -f services/hes/db/service_database_schema.sql
--   psql -f services/scada/db/service_database_schema.sql


