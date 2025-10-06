-- Ensure uuid
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Insert 500 demo customers (Amman area) matching existing columns
WITH seq AS (
  SELECT generate_series(1, 500) AS n
),
phones AS (
  SELECT n,
         ('+962-7-' || lpad(((random()*9999999)::int)::text, 7, '0'))::varchar(32) AS phone
  FROM seq
),
geo AS (
  -- Amman-ish
  SELECT n,
         (31.90 + random() * 0.12)::decimal(10,8) AS lat,
         (35.84 + random() * 0.16)::decimal(11,8) AS lng,
         ('Street ' || (1 + (random()*200)::int) || ', Amman')::text AS address,
         ('BLDG_' || lpad((1000 + n)::text, 6, '0'))::varchar(50) AS building_id
  FROM seq
)
INSERT INTO oms_customers (customer_id, phone, address, building_id, location_lat, location_lng, status)
SELECT  ('CUST_' || lpad((100000 + n)::text, 8, '0'))::varchar(64) AS customer_id,
        p.phone,
        g.address,
        g.building_id,
        g.lat,
        g.lng,
        'active'
FROM seq s
JOIN phones p USING (n)
JOIN geo g USING (n)
ON CONFLICT (customer_id) DO NOTHING;

-- Mapping table (if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'oms_outage_customers'
  ) THEN
    CREATE TABLE oms_outage_customers (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      outage_id UUID NOT NULL REFERENCES oms_outage_events(id) ON DELETE CASCADE,
      customer_id UUID NOT NULL REFERENCES oms_customers(id) ON DELETE CASCADE,
      linked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(outage_id, customer_id)
    );
    CREATE INDEX IF NOT EXISTS idx_ooc_outage ON oms_outage_customers(outage_id);
    CREATE INDEX IF NOT EXISTS idx_ooc_customer ON oms_outage_customers(customer_id);
  END IF;
END$$;

-- Link nearest customers to last 10 outages (10–30 each)
WITH recent_outages AS (
  SELECT id, event_latitude AS lat, event_longitude AS lng
  FROM oms_outage_events
  WHERE event_latitude IS NOT NULL AND event_longitude IS NOT NULL
  ORDER BY first_detected_at DESC
  LIMIT 10
),
ranked_customers AS (
  SELECT ro.id AS outage_id,
         c.id  AS customer_id,
         (abs(c.location_lat - ro.lat) + abs(c.location_lng - ro.lng)) AS geo_dist,
         row_number() OVER (PARTITION BY ro.id ORDER BY (abs(c.location_lat - ro.lat) + abs(c.location_lng - ro.lng))) AS rn
  FROM recent_outages ro
  JOIN oms_customers c
    ON c.location_lat IS NOT NULL AND c.location_lng IS NOT NULL
)
INSERT INTO oms_outage_customers (outage_id, customer_id)
SELECT outage_id, customer_id
FROM ranked_customers
WHERE rn <= (10 + (random()*20)::int)
ON CONFLICT DO NOTHING;

-- Quick check
SELECT
  (SELECT COUNT(*) FROM oms_customers) AS total_customers,
  (SELECT COUNT(*) FROM oms_outage_customers) AS total_links,
  (SELECT COUNT(DISTINCT outage_id) FROM oms_outage_customers) AS outages_with_customers;