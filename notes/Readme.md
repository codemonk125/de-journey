# Data Engineering Fundamentals: Topic Overview

This file summarises the main topics covered in the Week 1 study notes for data engineering fundamentals.

## Core themes

The notes introduce the foundations of modern data engineering: how data moves through systems, how it is stored and modeled, and how pipelines are made reliable and observable.

## Topics covered

### 1. What is data engineering
- Definition of a data engineer
- Typical responsibilities in a day-to-day workflow
- Importance of operational reliability and troubleshooting
- Introductory concept: idempotency

### 2. The data engineering lifecycle
- End-to-end flow: generation -> ingestion -> storage -> transformation -> serving
- Role of grain in understanding data at each stage
- Storage system types: data lake, warehouse, operational database
- The impedance mismatch between transactional and analytical systems

### 3. The undercurrents
- Security
- Data management
- DataOps
- Architecture
- Orchestration
- Software engineering practices
- Real-world failure examples and production habits

### 4. OLTP vs OLAP
- Transactional systems vs analytical systems
- ACID guarantees
- CRUD operations
- Why analytics should not run directly on OLTP databases

### 5. ETL vs ELT
- Traditional ETL pattern
- Modern ELT pattern
- Why the industry shifted to ELT in the cloud
- Raw data preservation and reprocessing benefits

### 6. Batch vs streaming
- Trade-offs between freshness, complexity and reprocessing
- Decision rule based on business impact of stale data
- Typical use cases and tools for both patterns

### 7. Data roles
- Data engineer
- Analytics engineer
- Data analyst
- Data scientist
- Role boundaries and tooling expectations
- Signals from job descriptions

### 8. Data modeling and warehousing
- Conceptual, logical and physical modeling
- Kimball vs Inmon approaches
- Facts vs dimensions
- Star schema design
- Grain selection
- Slowly changing dimensions (SCD Type 1, 2, 3)
- Data marts and warehouse design principles

### 9. Pipeline reliability
- Idempotency and duplicate prevention
- Schema evolution and change management
- Data quality dimensions: completeness, accuracy, consistency, timeliness, validity
- Common pipeline failure patterns
- Handling late-arriving data and ranking issues

### 10. Observability, lineage and governance
- Observability and pipeline health monitoring
- Data lineage and dependency tracing
- Governance policies and access controls
- Key regulations: GDPR, DPDP Act, HIPAA, PCI-DSS

### 11. Data lakes, file formats and partitioning
- Medallion architecture: bronze, silver, gold
- Data lake vs warehouse vs lakehouse
- Schema on read vs schema on write
- Row-based vs columnar file formats
- Parquet and ORC
- Partitioning, partition pruning and the small-files problem
- Clustering and storage optimisation

### 12. Ingestion patterns
- CDC (Change Data Capture)
- Message queues and Kafka
- Reverse ETL
- Full vs incremental loads
- Paginated APIs and rate-limit handling

### 13. Cloud and AWS for data engineering
- IaaS, PaaS, SaaS models
- Core AWS services for data engineering
- S3, Glue, Athena, Redshift, Lambda, Kinesis, EventBridge, CloudWatch

### 14. Case study: Dream11
- Large-scale fantasy sports platform example
- OLTP vs OLAP in production
- Batch and streaming coexistence
- Lessons from real-world architecture decisions

### 15. The modern data stack
- Traditional monolithic ETL stack vs modern modular stack
- Core components: ingestion, storage, warehouse, transformation, serving, orchestration
- Why cloud-native modular tools won in industry
- Tool landscape overview

### 16. dbt
- dbt as a SQL compiler and DAG runner
- How dbt works in an ELT architecture
- Staging and marts conventions
- Testing, lineage and model documentation

### 17. Apache Airflow
- DAGs and dependency orchestration
- Tasks, operators, workers, scheduler and web UI
- Why Airflow is used over plain cron
- Retry, monitoring and backfill management

### 18. Data security and masking
- Static masking, dynamic masking, tokenisation
- Need to mask PII before analyst-facing access
- Protecting sensitive customer and health information

### 19. Self-check questions
- Practice questions to validate understanding of concepts like data roles, grain and modeling

### 20. Further reading
- Recommended books and docs for deeper learning
- dbt, Airflow and Snowflake documentation

## Quick study summary

The notes build a practical mental model for data engineering:

- Source systems generate data
- Data is ingested into lakes or warehouses
- Transformations create trusted, queryable datasets
- Pipelines must be reliable, monitored and governed
- Modern stacks rely on cloud, SQL, orchestration and testing

## Suggested exam themes

If you're revising for interviews or assessments, focus on:
- ETL vs ELT
- OLTP vs OLAP
- Batch vs streaming
- Data modeling and grain
- Idempotency and data quality
- dbt and Airflow fundamentals
- Data warehousing and lakehouse concepts
- Security, governance and lineage

---

This overview is based on the Week 1 fundamentals notes from the de-journey learning repository.
