## Enterprise project organization (under construction)

This folder proposes a clean, component-centric structure without changing the running setup. Source files remain in their original locations until approved migration.

Top-level domains:
- services/hes: KAIFA HES mock producer, consumer, and database assets
- services/scada: SCADA producer and consumer
- ops: Deployment and gateway assets (Docker Compose, APISIX configs, monitoring)

Planned structure:

services/
  hes/
    producer/
      - web2_kafka_service.py (current: apisix-workshop/web2_kafka_service.py)
    consumer/
      - hes_kaifa_consumer.py (current: Kaifa-HES-Events/hes_kaifa_consumer.py)
      - run_consumer.py (current: Kaifa-HES-Events/run_consumer.py)
      - config/ (flags, env, sample)
    db/
      - database_schema.sql (current: apisix-workshop/database_schema.sql)
      - create_database.py (current: apisix-workshop/create_database.py)
      - database_config.py (current: apisix-workshop/database_config.py)
      - test_database.py (current: apisix-workshop/test_database.py)
  scada/
    producer/
      - scada_kafka_service.py (current: apisix-workshop/scada_kafka_service.py)
    consumer/
      - scada_consumer.py (current: Kaifa-HES-Events/scada_consumer.py)
      - outbox/: JSON output directory (current: Kaifa-HES-Events/SCADA)

ops/
  docker/
    - docker-compose.yml (current: apisix-workshop/docker-compose.yml)
  apisix/
    - apisix_conf/config.yaml
    - lua_plugins/, lua_filters/, lua_routes/

Migration plan (safe, incremental):
1) Copy files into this structure and update imports/paths behind a feature flag.
2) Update docker-compose service mounts to new paths.
3) Update APISIX upstreams/routes if any service path changed.
4) Run smoke tests and revert if issues.

Note: Until approved, this is documentation-only. No runtime paths are changed yet.


