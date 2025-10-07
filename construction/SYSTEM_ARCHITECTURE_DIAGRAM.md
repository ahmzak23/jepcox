# OMS System Architecture Diagram

## Professional System Architecture Overview

This document provides a comprehensive visual representation of the Outage Management System (OMS) architecture, showing the complete data flow, service interactions, and system components.

## High-Level System Architecture

```mermaid
graph TB
    %% External Systems
    subgraph "External Data Sources"
        SCADA[SCADA System<br/>Breaker Trips & Alarms]
        KAIFA[Kaifa Smart Meters<br/>Last-Gasp Events]
        ONU[ONU Fiber Devices<br/>Power Loss Events]
        CALL[Call Center<br/>Customer Reports]
    end

    %% API Gateway Layer
    subgraph "API Gateway Layer"
        APISIX[Apache APISIX<br/>API Gateway<br/>Port: 9080]
        DASH[APISIX Dashboard<br/>Port: 9000]
    end

    %% Service Layer
    subgraph "Service Layer"
        subgraph "Producer Services"
            SCADA_PROD[SCADA Producer<br/>Port: 9086]
            KAIFA_PROD[Kaifa Producer<br/>Port: 9085]
            ONU_PROD[ONU Producer<br/>Port: 9088]
            CALL_PROD[Call Center Producer<br/>Port: 9087]
        end
        
        subgraph "Consumer Services"
            SCADA_CONS[SCADA Consumer]
            KAIFA_CONS[Kaifa Consumer]
            ONU_CONS[ONU Consumer]
            CALL_CONS[Call Center Consumer]
        end
    end

    %% Message Queue
    subgraph "Message Queue Infrastructure"
        ZK[Zookeeper<br/>Port: 2181]
        KAFKA[Apache Kafka<br/>Port: 9093]
        KAFKA_UI[Kafka UI<br/>Port: 8080]
    end

    %% OMS Core System
    subgraph "OMS Core System"
        OMS_API[OMS Ingestion API<br/>FastAPI Service<br/>Port: 9100]
        OMS_MIG[OMS Migrator<br/>Batch Processing]
        OMS_DB[(OMS PostgreSQL<br/>Correlated Database)]
    end

    %% User Interfaces
    subgraph "User Interfaces"
        OMS_DASH[OMS Dashboard<br/>Port: 9200]
        OMS_ANAL[OMS Analytics<br/>Port: 9300]
    end

    %% Data Flow Connections
    SCADA --> APISIX
    KAIFA --> APISIX
    ONU --> APISIX
    CALL --> APISIX

    APISIX --> SCADA_PROD
    APISIX --> KAIFA_PROD
    APISIX --> ONU_PROD
    APISIX --> CALL_PROD

    SCADA_PROD --> KAFKA
    KAIFA_PROD --> KAFKA
    ONU_PROD --> KAFKA
    CALL_PROD --> KAFKA

    KAFKA --> SCADA_CONS
    KAFKA --> KAIFA_CONS
    KAFKA --> ONU_CONS
    KAFKA --> CALL_CONS

    SCADA_CONS --> OMS_API
    KAIFA_CONS --> OMS_API
    ONU_CONS --> OMS_API
    CALL_CONS --> OMS_API

    OMS_API --> OMS_DB
    OMS_MIG --> OMS_DB

    OMS_DB --> OMS_DASH
    OMS_DB --> OMS_ANAL

    ZK --> KAFKA
    KAFKA --> KAFKA_UI

    %% Styling
    classDef external fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef gateway fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef service fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef queue fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef oms fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef ui fill:#f1f8e9,stroke:#33691e,stroke-width:2px
    classDef database fill:#e0f2f1,stroke:#004d40,stroke-width:2px

    class SCADA,KAIFA,ONU,CALL external
    class APISIX,DASH gateway
    class SCADA_PROD,KAIFA_PROD,ONU_PROD,CALL_PROD,SCADA_CONS,KAIFA_CONS,ONU_CONS,CALL_CONS service
    class ZK,KAFKA,KAFKA_UI queue
    class OMS_API,OMS_MIG oms
    class OMS_DASH,OMS_ANAL ui
    class OMS_DB database
```

## Detailed Data Flow Architecture

```mermaid
sequenceDiagram
    participant SCADA as SCADA System
    participant APISIX as APISIX Gateway
    participant PROD as Producer Service
    participant KAFKA as Kafka
    participant CONS as Consumer Service
    participant OMS as OMS API
    participant DB as OMS Database
    participant DASH as Dashboard

    Note over SCADA,DASH: Real-Time Outage Event Processing Flow

    SCADA->>APISIX: 1. Breaker Trip Event
    APISIX->>PROD: 2. Route to SCADA Producer
    PROD->>KAFKA: 3. Publish to scada-outage-topic
    
    KAFKA->>CONS: 4. Consume Event
    CONS->>DB: 5. Store Event in Service DB
    CONS->>OMS: 6. POST /api/oms/events/correlate
    
    OMS->>DB: 7. Call oms_correlate_events()
    DB-->>OMS: 8. Return Correlated Outage ID
    OMS-->>CONS: 9. Return Event UUID
    
    Note over OMS,DB: Correlation Logic:<br/>- Spatial Proximity (1000m)<br/>- Temporal Window (30min)<br/>- Confidence Scoring
    
    CONS->>DASH: 10. Update Dashboard
    DASH->>DB: 11. Query Outage Data
    DB-->>DASH: 12. Return Correlated Events
```

## Network Topology & Data Correlation

```mermaid
graph LR
    subgraph "Network Hierarchy"
        SUB["Substations<br/>SS001-SS020"]
        FEED["Feeders<br/>33kV Lines"]
        DP["Distribution Points<br/>Local Networks"]
        CUST["Customers<br/>End Users"]
    end

    subgraph "Data Sources"
        SCADA_EVENTS["SCADA Events<br/>Breaker Trips"]
        METER_EVENTS["Smart Meter Events<br/>Last-Gasp Signals"]
        ONU_EVENTS["ONU Events<br/>Power Loss"]
        CALL_EVENTS["Call Center<br/>Customer Reports"]
    end

    subgraph "Correlation Engine"
        CORRELATE["oms_correlate_events()<br/>PostgreSQL Function"]
        CONFIDENCE["Confidence Scoring<br/>SCADA: 1.0<br/>Kaifa: 0.8<br/>ONU: 0.6<br/>Call: 0.4"]
    end

    subgraph "Output"
        OUTAGE["Correlated Outage Events"]
        CREW["Crew Assignments"]
        NOTIFY["Customer Notifications"]
    end

    SUB --> FEED
    FEED --> DP
    DP --> CUST

    SCADA_EVENTS --> CORRELATE
    METER_EVENTS --> CORRELATE
    ONU_EVENTS --> CORRELATE
    CALL_EVENTS --> CORRELATE

    CORRELATE --> CONFIDENCE
    CONFIDENCE --> OUTAGE
    OUTAGE --> CREW
    OUTAGE --> NOTIFY

    classDef network fill:#e3f2fd,stroke:#0277bd,stroke-width:2px
    classDef source fill:#fff8e1,stroke:#f57f17,stroke-width:2px
    classDef engine fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef output fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px

    class SUB,FEED,DP,CUST network
    class SCADA_EVENTS,METER_EVENTS,ONU_EVENTS,CALL_EVENTS source
    class CORRELATE,CONFIDENCE engine
    class OUTAGE,CREW,NOTIFY output
```

## Service Integration Architecture

```mermaid
graph TB
    subgraph "Service Domains"
        subgraph "SCADA Domain"
            SCADA_SVC[SCADA Service]
            SCADA_DB[(SCADA Database)]
        end
        
        subgraph "Kaifa Domain"
            KAIFA_SVC[Kaifa Service]
            KAIFA_DB[(Kaifa Database)]
        end
        
        subgraph "ONU Domain"
            ONU_SVC[ONU Service]
            ONU_DB[(ONU Database)]
        end
        
        subgraph "Call Center Domain"
            CALL_SVC[Call Center Service]
            CALL_DB[(Call Center Database)]
        end
    end

    subgraph "OMS Integration Layer"
        OMS_CORE[OMS Core Engine]
        OMS_CORRELATED[(OMS Correlated DB)]
    end

    subgraph "Cross-Cutting Concerns"
        LOGGING[Logging & Monitoring]
        SECURITY[Security & Auth]
        CORS[CORS & API Gateway]
    end

    SCADA_SVC --> SCADA_DB
    KAIFA_SVC --> KAIFA_DB
    ONU_SVC --> ONU_DB
    CALL_SVC --> CALL_DB

    SCADA_SVC --> OMS_CORE
    KAIFA_SVC --> OMS_CORE
    ONU_SVC --> OMS_CORE
    CALL_SVC --> OMS_CORE

    OMS_CORE --> OMS_CORRELATED

    OMS_CORE --> LOGGING
    OMS_CORE --> SECURITY
    OMS_CORE --> CORS

    classDef domain fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef oms fill:#fce4ec,stroke:#e91e63,stroke-width:2px
    classDef cross fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px
    classDef database fill:#e0f2f1,stroke:#00695c,stroke-width:2px

    class SCADA_SVC,KAIFA_SVC,ONU_SVC,CALL_SVC domain
    class OMS_CORE oms
    class LOGGING,SECURITY,CORS cross
    class SCADA_DB,KAIFA_DB,ONU_DB,CALL_DB,OMS_CORRELATED database
```

## Technology Stack & Ports

```mermaid
graph LR
    subgraph "Frontend Layer"
        DASH_UI[Dashboard UI<br/>Port: 9200]
        ANAL_UI[Analytics UI<br/>Port: 9300]
    end

    subgraph "API Gateway"
        APISIX_GW[APISIX Gateway<br/>Port: 9080]
        APISIX_ADMIN[APISIX Admin<br/>Port: 9180]
        APISIX_DASH[APISIX Dashboard<br/>Port: 9000]
    end

    subgraph "Application Services"
        OMS_API_SVC[OMS API<br/>Port: 9100]
        SCADA_PROD_SVC[SCADA Producer<br/>Port: 9086]
        KAIFA_PROD_SVC[Kaifa Producer<br/>Port: 9085]
        ONU_PROD_SVC[ONU Producer<br/>Port: 9088]
        CALL_PROD_SVC[Call Center Producer<br/>Port: 9087]
    end

    subgraph "Message Infrastructure"
        KAFKA_MSG[Kafka<br/>Port: 9093]
        ZK_COORD[Zookeeper<br/>Port: 2181]
        KAFKA_MGMT[Kafka UI<br/>Port: 8080]
    end

    subgraph "Data Layer"
        POSTGRES_DB[PostgreSQL<br/>OMS Database]
    end

    DASH_UI --> APISIX_GW
    ANAL_UI --> APISIX_GW
    APISIX_GW --> OMS_API_SVC
    APISIX_GW --> SCADA_PROD_SVC
    APISIX_GW --> KAIFA_PROD_SVC
    APISIX_GW --> ONU_PROD_SVC
    APISIX_GW --> CALL_PROD_SVC

    SCADA_PROD_SVC --> KAFKA_MSG
    KAIFA_PROD_SVC --> KAFKA_MSG
    ONU_PROD_SVC --> KAFKA_MSG
    CALL_PROD_SVC --> KAFKA_MSG

    KAFKA_MSG --> ZK_COORD
    KAFKA_MSG --> KAFKA_MGMT

    OMS_API_SVC --> POSTGRES_DB

    classDef frontend fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef gateway fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef service fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef message fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef data fill:#e0f2f1,stroke:#004d40,stroke-width:2px

    class DASH_UI,ANAL_UI frontend
    class APISIX_GW,APISIX_ADMIN,APISIX_DASH gateway
    class OMS_API_SVC,SCADA_PROD_SVC,KAIFA_PROD_SVC,ONU_PROD_SVC,CALL_PROD_SVC service
    class KAFKA_MSG,ZK_COORD,KAFKA_MGMT message
    class POSTGRES_DB data
```

## Toolchain & Technology Stack

### **Core Technologies**
- **API Gateway**: Apache APISIX 2.13.1 (Alpine) - High-performance API gateway with built-in plugins
- **Message Queue**: Apache Kafka 7.4.0 with Zookeeper 3.4.15 - Event streaming and real-time data processing
- **Database**: PostgreSQL with PostGIS extension - Relational database with spatial capabilities
- **Containerization**: Docker Compose - Container orchestration and service management

### **Development Stack**
- **Backend Services**: Python 3.9 (FastAPI, Flask) - RESTful APIs and microservices
- **Database ORM**: psycopg2, SQLAlchemy - Database connectivity and ORM
- **Message Processing**: kafka-python - Kafka client for Python
- **Web UI**: HTML5, JavaScript, CSS3 - Frontend dashboards and analytics

### **Infrastructure Tools**
- **Configuration Management**: YAML-based configs for APISIX, Docker Compose
- **Service Discovery**: Docker networking with service names
- **Monitoring**: Kafka UI, APISIX Dashboard, custom logging
- **Data Migration**: Python scripts with psql for database operations

### **Development Workflow**
- **Version Control**: Git with feature branches
- **Container Registry**: Docker Hub for base images
- **Environment Management**: Docker Compose with environment variables
- **Testing**: Unit tests with pytest, integration testing with Docker

This toolchain provides a modern, scalable foundation for real-time event processing and intelligent outage management.

## Key Architecture Principles

### 1. **Microservices Architecture**
- Each service domain (SCADA, Kaifa, ONU, Call Center) operates independently
- Services communicate through well-defined APIs and message queues
- Clear separation of concerns and data ownership

### 2. **Event-Driven Architecture**
- Real-time event processing through Apache Kafka
- Asynchronous communication between services
- Event sourcing for audit trails and replay capabilities

### 3. **API-First Design**
- Apache APISIX as the central API gateway
- RESTful APIs for all service interactions
- CORS support for cross-origin requests

### 4. **Data Correlation Engine**
- Intelligent correlation of events from multiple sources
- Spatial and temporal proximity algorithms
- Confidence scoring based on source reliability

### 5. **Scalable Infrastructure**
- Containerized services with Docker Compose
- Horizontal scaling capabilities
- Load balancing through APISIX

### 6. **Observability & Monitoring**
- Comprehensive logging across all services
- Kafka UI for message queue monitoring
- APISIX Dashboard for API gateway management

## Deployment Architecture

The system is deployed using Docker Compose with the following key characteristics:

- **Single-host deployment** for development and testing
- **Service discovery** through Docker networking
- **Volume persistence** for databases and logs
- **Health checks** and restart policies
- **Environment variable** configuration

## Security Considerations

- **API Gateway** provides centralized security controls
- **CORS policies** configured for cross-origin requests
- **Service isolation** through Docker networking
- **Database access** restricted to application services
- **Audit trails** for all event processing

This architecture provides a robust, scalable foundation for intelligent outage management that can handle high-volume event processing while maintaining data consistency and system reliability.
