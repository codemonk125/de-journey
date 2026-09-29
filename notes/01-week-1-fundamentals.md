# Data Engineering Fundamentals: Study Notes

Beginner-friendly notes covering the core concepts of data engineering: the lifecycle, storage, modeling, pipelines, and the modern data stack. Organised by topic so you can read top to bottom or jump to a section.

**Practice:** test yourself with [01-week-1-mcq-practice.md](01-week-1-mcq-practice.md) (28 questions with an answer key).

## Contents

1. [What is data engineering](#1-what-is-data-engineering)
2. [The data engineering lifecycle](#2-the-data-engineering-lifecycle)
3. [The undercurrents](#3-the-undercurrents)
4. [OLTP vs OLAP](#4-oltp-vs-olap)
5. [ETL vs ELT](#5-etl-vs-elt)
6. [Batch vs streaming](#6-batch-vs-streaming)
7. [Data roles](#7-data-roles)
8. [Data modeling and warehousing](#8-data-modeling-and-warehousing)
9. [Pipeline reliability](#9-pipeline-reliability-idempotency-schema-evolution-quality)
10. [Observability, lineage and governance](#10-observability-lineage-and-governance)
11. [Data lakes, file formats and partitioning](#11-data-lakes-file-formats-and-partitioning)
12. [Ingestion patterns](#12-ingestion-patterns-cdc-queues-reverse-etl)
13. [Cloud and AWS for data engineering](#13-cloud-and-aws-for-data-engineering)
14. [Case study: Dream11](#14-case-study-dream11)
15. [The modern data stack](#15-the-modern-data-stack)
16. [dbt](#16-dbt)
17. [Apache Airflow](#17-apache-airflow)
18. [Data security and masking](#18-data-security-and-masking)
19. [Self-check questions](#19-self-check-questions)
20. [Further reading](#20-further-reading)

---

## 1. What is data engineering

A data engineer builds and maintains the systems that move data from where it is created to where it is useful.

**A typical day**
- Morning: check overnight pipeline runs, read logs, fix failures
- Mid-morning: build pipelines, write transformation logic and tests, review code
- Midday: meet analytics teams, software teams and stakeholders
- Afternoon: optimisation, schema design, monitoring setup
- Throughout: investigating why numbers look wrong

**Key term: idempotency.** Running an operation multiple times produces the same result as running it once. Pipelines fail and get rerun, so non-idempotent pipelines create duplicates. See [section 9](#9-pipeline-reliability-idempotency-schema-evolution-quality).

---

## 2. The data engineering lifecycle

```
Generation -> Ingestion -> Storage -> Transformation -> Serving
```

**Grain** means "what does one row represent?" Stating the grain at each stage is a useful habit.

| Stage | What happens | One row represents |
|---|---|---|
| Generation | Source systems produce data: application databases, IoT sensors, APIs, message queues, flat files, SaaS tools. Data engineers do not build these systems but must understand them deeply. | One raw event or transaction, as the source recorded it |
| Ingestion | Moving data from sources into your infrastructure. **Batch** collects on a schedule; **streaming** captures data continuously as it is created. | One raw record as it arrived, timestamped at ingestion |
| Storage | Where data lives after ingestion (see table below). | Raw layer: one raw record. Warehouse: one modeled fact or dimension record |
| Transformation | Raw data is cleaned, joined, aggregated and modeled. This is where dbt lives. | One record at whatever level of aggregation the transformation produces |
| Serving | Data is delivered to analysts, data scientists, dashboards, ML models and applications. | One analytical or reporting entity at the required business grain |

**Storage systems**

| System | What it is | When you use it |
|---|---|---|
| Data lake (S3, GCS) | Raw files, any format, cheap | Store everything on arrival |
| Data warehouse (Snowflake, BigQuery) | Structured and queryable | Cleaned, modeled data |
| Operational database (Postgres, MySQL) | Powers applications | Source-system storage |

**The impedance mismatch.** Source systems are optimised for transactions: row by row, one record at a time, with ACID guarantees. Analytics needs data that is columnar, compressed and partitioned. Bridging that gap is much of the job. Three common patterns:
1. Land raw data first in the lake exactly as generated, and transform later
2. Stream through a message queue (Kafka) to decouple generation speed from storage speed
3. Use CDC (Change Data Capture) to capture only what changed, not a full dump

---

## 3. The undercurrents

These run beneath every stage of the lifecycle.

| Undercurrent | What breaks if you ignore it |
|---|---|
| Security | PII exposed, credentials leaked, compliance violation, breach |
| Data management | Nobody knows what columns mean; teams report different numbers |
| DataOps | Pipelines break silently; wrong numbers reach leadership; no alerting |
| Architecture | Built for 10 GB, falls over at 1 TB, forcing a rewrite |
| Orchestration | Jobs run in the wrong order; downstream tables end up empty |
| Software engineering | Scripts only work on one laptop; no tests; break when a column is renamed |

**Production practices**

- **Security:** mask PII before analyst-facing tables; never put credentials in code (use environment variables or a secrets manager); apply row-level permissions; treat GDPR, HIPAA and local privacy law compliance as part of the job
- **Data management:** a *data catalog* (searchable directory of datasets), a *data dictionary* (plain-English column meanings), *lineage* (where data came from and what touched it), and a named *owner* for every dataset
- **DataOps:** track every pipeline run, alert before analysts notice problems, automate data quality checks, keep all pipeline code in version control, and make runs reproducible (same inputs, same outputs)
- **Architecture:** always land raw data first, keep it, and transform from the raw copy. A wrong architecture on day one can take months to fix
- **Orchestration:** tools like Airflow manage dependencies, retries and alerts. Without one, cron jobs can run in the wrong order without anyone noticing
- **Software engineering:** small modular functions instead of 200-line scripts, retry logic for API failures, tests for transformation logic, and Docker so code runs identically everywhere

**Failure examples**
- *Security ignored:* an analyst queries a raw table containing unhashed customer emails, exports it to a spreadsheet and shares it with "anyone with the link". That is a GDPR violation.
- *Orchestration ignored:* pipeline 3 runs before pipeline 1 finishes, produces empty records, and a dashboard shows zero orders. A team spends a meeting investigating a problem that does not exist.

---

## 4. OLTP vs OLAP

| Axis | OLTP | OLAP |
|---|---|---|
| Purpose | Power applications, record transactions | Power analytics, answer business questions |
| Query type | Simple, fast, individual rows | Complex, slow, millions of rows |
| Data model | Normalized: many small tables | Denormalized: fewer, wider tables |
| Data age | Current state | Historical (months or years) |
| Users | Applications and software systems | Analysts, data scientists, dashboards |

**Why not run analytics on the OLTP database?** A heavy analytical query on a production Postgres instance can take minutes, hold resources, and slow the application for real users.

**ACID (OLTP guarantees)**
- **Atomicity:** a transaction fully completes or fully fails, with no partial states
- **Consistency:** a transaction moves the database from one valid state to another
- **Isolation:** concurrent transactions do not interfere with each other
- **Durability:** committed transactions survive crashes

**CRUD**

| Letter | Operation | SQL |
|---|---|---|
| C | Create | `INSERT` |
| R | Read | `SELECT` |
| U | Update | `UPDATE` |
| D | Delete | `DELETE` |

---

## 5. ETL vs ELT

**ETL (older pattern):** Extract, then Transform on a separate server, then Load into the warehouse.
- Transformation happens *before* loading
- Storage was expensive, so only clean data was kept
- Typical tools: Informatica, Talend, SSIS

**ELT (modern pattern):** Extract, then Load raw data into the warehouse, then Transform inside the warehouse.
- Transformation happens *after* loading
- Raw data is always preserved

**Why the industry shifted to ELT**
1. **Cloud storage became cheap:** you can afford to keep raw data
2. **Cloud warehouses became powerful:** Snowflake and BigQuery transform millions of rows in seconds with SQL, so no separate transformation server is needed
3. **Preserving raw data is safer:** if transformation logic has a bug, you reprocess from raw. Under ETL the raw data may be gone.

| Concept | Example tools |
|---|---|
| Extract + load | Fivetran, Airbyte, custom Python |
| Transform | dbt inside Snowflake |
| OLTP source | Postgres, MySQL |
| OLAP destination | Snowflake, BigQuery |

---

## 6. Batch vs streaming

| Axis | Batch | Streaming |
|---|---|---|
| Data freshness | Minutes to hours old | Seconds to milliseconds |
| Complexity | Lower: easier to build and debug | Higher: late data, exactly-once semantics, state management |
| Reprocessing | Easy: rerun the job | Harder: needs a replayable log or retained events |
| Use cases | Reporting, analytics, ML training | Fraud detection, live dashboards, IoT |
| Typical tools | Python, Airflow, dbt, Spark batch | Kafka, Spark Structured Streaming, Kinesis |

**Decision rule.** Ask: *what is the consequence of stale data?*
- "Inconvenient" leads to **batch**
- "Dangerous, fraudulent, or financially catastrophic" leads to **streaming**

| Scenario | Choice |
|---|---|
| Hospital heart-rate monitoring | Streaming |
| Monthly sales report | Batch |
| Card fraud detection | Streaming |
| ML model training | Batch |
| Station-availability dashboard where 5-minute-old data is fine | Batch |

Batch still dominates in practice. Do not add streaming complexity unless the use case needs it.

---

## 7. Data roles

| Role | Ships | Primary tools | Output used by |
|---|---|---|---|
| Data engineer | Pipelines, storage, infrastructure | Python, SQL, Airflow, Spark | Everyone downstream |
| Analytics engineer | Clean, tested, documented SQL models | SQL, dbt | Analysts, dashboards |
| Data analyst | Reports, dashboards, ad-hoc insights | SQL, BI tools | Business stakeholders |
| Data scientist | Predictive models, experiments, forecasts | Python, ML libraries | Product teams, executives |

**Mental model:** the data engineer builds the road, the analytics engineer adds markings and signs, the analyst drives and reports back, and the data scientist predicts where the road should go next.

**Boundaries**
- The DE loads raw data into the warehouse, the AE turns it into trusted models, and the DA queries those models
- DE work is invisible when it works and noticed when it breaks
- AE work ships as dbt models with tests and documentation

**Job-posting signals**
- **DE:** Airflow, Spark, dbt, warehouse, ingestion, orchestration, Python, cloud
- **AE:** dbt heavily, SQL, data modeling, documentation, testing, Looker/Tableau
- **DA:** SQL, Tableau/Power BI/Looker, Excel, reporting, stakeholder communication
- **DS:** Python, ML, statistics, experimentation, A/B testing, TensorFlow/PyTorch

---

## 8. Data modeling and warehousing

### Levels of modeling

| Level | What it is | Audience |
|---|---|---|
| Conceptual | Entities and relationships: boxes and lines, no columns | Business stakeholders |
| Logical | Tables, columns, types, relationships, independent of any database | Data architects |
| Physical | Actual DDL (`CREATE TABLE`) for a specific database | Data engineers |

**Two schools:**
- **Kimball:** dimensional modeling and star schemas, optimised for analytics, built bottom-up. Most modern teams use this.
- **Inmon:** a normalized enterprise warehouse with data marts derived from it, built top-down. Less common today.

### Facts and dimensions

- **Fact tables** store measurable business events. One row is one event at a chosen grain, with numeric measures you can aggregate (revenue, quantity, duration) and foreign keys to dimensions.
- **Dimension tables** store context: who, what, where, when, why (customer, product, store, date).

**Star schema**

```
            dim_customer
                 |
dim_date  --  fct_orders  --  dim_product
                 |
             dim_store
```

**Choosing the grain.** Decide what one fact row means *before* designing anything else. For an e-commerce order with line items, the safest grain is usually **one row per order line item**, because you can always roll it up to order level but cannot break an order-level row back down.

### Slowly changing dimensions (SCDs)

How do you handle a dimension attribute that changes, such as a customer moving city?

**Type 1: overwrite.** No history is kept.
```
Before: customer_id=1, city=Mumbai
After:  customer_id=1, city=Pune
```
Downside: you can never answer "what city was this customer in last year?"

**Type 2: add a new row.** Full history is preserved. This is the most important type.
```
customer_id=1, city=Mumbai, effective_from=2023-01-01, effective_to=2024-06-01, is_current=False
customer_id=1, city=Pune,   effective_from=2024-06-01, effective_to=9999-12-31, is_current=True
```
Three columns make it work: `effective_from`, `effective_to`, `is_current`.

**Type 3: add a column.** Keeps only the current and previous value. Rarely used.

### Data marts

A subset of the warehouse focused on one business domain or team (marketing, finance, operations). They exist for performance, access control and clarity.

> Good data modeling is the difference between a warehouse analysts love and one they route around.

---

## 9. Pipeline reliability: idempotency, schema evolution, quality

### Idempotency

**Non-idempotent (broken):**
```sql
INSERT INTO orders SELECT * FROM raw_orders WHERE date = yesterday;
-- Run twice = every order duplicated, revenue doubled
```

**Idempotent (correct):**
```sql
DELETE FROM orders WHERE date = yesterday;
INSERT INTO orders SELECT * FROM raw_orders WHERE date = yesterday;
-- Run ten times = same result every time
```

`MERGE` (upsert on a unique key) achieves the same in one statement. Overwriting by partition also works.

*Interview answer:* "To avoid duplicates if a pipeline runs twice, I make it idempotent, using delete-then-insert by partition or a MERGE keyed on a unique ID."

### Schema evolution

Source systems change without warning.

| Change | Impact | Strategy |
|---|---|---|
| New column added | Usually safe | Add to the model if needed |
| Column removed | Breaks pipelines that reference it | Catch with validation, alert |
| Column renamed | Breaks the pipeline | Catch early, alert, fix the reference |
| Data type changed | Silent failures | Schema validation on ingestion |

**Production habit:** validate the schema on every ingestion run. If it changes unexpectedly, fail loudly and alert. Never silently load wrong data.

### Data quality: five dimensions

| Dimension | Question | Failure example |
|---|---|---|
| Completeness | Are all expected records present? | 800 orders yesterday, 200 today: real or broken? |
| Accuracy | Are values correct? | A temperature sensor reports 999 °C |
| Consistency | Does data agree across systems? | Warehouse revenue does not match CRM revenue |
| Timeliness | Is data fresh enough? | A daily dashboard showing 3-day-old data |
| Validity | Do values match the expected format or range? | An age column containing -5 or 200 |

### Other common failure patterns

- **Row count jumps unexpectedly** (for example 500k to 750k with 500k unique customers): suspect duplicates introduced by a join fan-out (many-to-many) or a non-idempotent rerun
- **Load succeeds but writes 0 rows with no errors:** check ingestion first; the source may have returned nothing
- **Ranking changes when the data has not:** ties combined with a non-deterministic `ROW_NUMBER()`. Add a tiebreaker column to the `ORDER BY`
- **Late-arriving records:** events whose event time is older than records already processed. Design for them with reprocessing windows or upserts

---

## 10. Observability, lineage and governance

**Observability:** knowing what your pipeline is doing at any moment: rows processed, duration versus last week, which task is running.

**Data lineage:** tracing where data came from and what touched it.
```
fct_revenue <- int_orders_cleaned <- stg_orders <- raw.orders <- source API
```
With lineage, you can find a bug in minutes instead of hours. dbt generates lineage automatically (`dbt docs`).

**Governance:** the rules for how data is used, who can access it, and how long it is kept.

**Key regulations**
- **GDPR** (EU): users can request deletion of their data
- **DPDP Act** (India): the Digital Personal Data Protection Act, 2023
- **HIPAA** (US): healthcare data
- **PCI-DSS**: payment card data

**In practice:** never store card numbers in plain text, support targeted deletes ("right to be forgotten"), and respect rules about data leaving certain regions.

---

## 11. Data lakes, file formats and partitioning

### Data lakes and medallion architecture

A **data lake** is a central repository that stores raw data in its native format until it is needed. Principle: *store first, ask questions later.*

```
Bronze (raw)     exact copy of the source, never modified, append-only
      |
Silver (cleaned) validated, deduplicated, standardised
      |
Gold (curated)   business-ready, aggregated, ready for serving
```

### Lake vs warehouse vs lakehouse

| Axis | Data lake | Data warehouse | Lakehouse |
|---|---|---|---|
| Data format | Any, raw files | Structured tables | Any |
| Schema | Schema on read | Schema on write | Both |
| Storage cost | Very cheap (S3) | Higher | Cheap (S3-based) |
| Query performance | Slow without optimisation | Fast | Fast (Delta/Iceberg) |
| Typical users | DEs, data scientists | Analysts, BI tools | Everyone |
| Tools | S3 + Spark | Snowflake, Redshift | Databricks, Delta Lake |

- **Schema on write** (warehouse): define columns and types before loading. The load fails if the data does not match.
- **Schema on read** (lake): store the raw file and define the schema at query time. Flexible, but errors surface later.

One line each:
- Lake = store everything, figure it out later
- Warehouse = store only what you have already processed
- Lakehouse = store everything, queryable as fast as a warehouse

### File formats

**Row-based**

| Format | Traits | Use when |
|---|---|---|
| CSV | Human-readable, universal; no schema enforcement or compression; slow for analytics | Exchanging data externally, or humans need to read it |
| JSON | Human-readable, nested structures; verbose because field names repeat every row | API responses, semi-structured data, event logs |
| Avro | Binary, schema stored with the data (good for schema evolution); heavily used with Kafka | Streaming pipelines, write-heavy ingestion |

**Columnar**

*Why columnar wins for analytics:* for `SELECT AVG(revenue) FROM orders`, a row format reads every column of every row; a columnar format reads only the `revenue` column. On a 50-column table that can mean roughly 50x less data scanned.

- **Parquet:** the standard columnar format in the modern stack. Typically several times smaller than CSV, with the schema embedded in the file. Optimised for Spark, Snowflake, Athena and BigQuery. Use for S3 lakes, Snowflake loading and Spark processing.
- **ORC:** similar to Parquet, historically used in Hive/Hadoop. Less common today; know it exists.

### Partitioning and clustering

**Partitioning** splits data into separate files or folders by column value.

```
s3://bucket/orders/
    year=2024/month=01/day=01/data.parquet
    year=2024/month=01/day=02/data.parquet
```

A query with `WHERE date = '2024-01-15'` reads only the matching folder. This is **partition pruning**: the engine skips every non-matching partition.

- **Good partition columns:** date, region, country
- **Bad partition columns:** `user_id` (too many values gives millions of tiny files) and booleans (too few values gives almost no benefit)

**The small-files problem.** Over-partitioning, or many tiny writes, creates huge numbers of small files, and per-file overhead makes queries slow. The fix is **compaction**: periodically merge small files into larger ones.

**Clustering** sorts data *within* a partition by a column (Snowflake clustering keys; Spark sort-within-partition).

| | Partitioning | Clustering |
|---|---|---|
| What it does | Separate physical files/folders | Sorted order within a file |

Partitioning is a physical storage optimisation. The grain of the data does not change.

### How it fits together

```
Source -> raw JSON/CSV -> S3 Bronze (data lake)
              |
   Spark converts to Parquet, partitioned by date -> S3 Silver
              |
   Snowflake external stage reads the Parquet
              |
   dbt transforms -> Gold tables
              |
   Analysts query: fast because columnar + partitioned
```

---

## 12. Ingestion patterns: CDC, queues, reverse ETL

**CDC (Change Data Capture).** Captures only rows that were inserted, updated or deleted since the last run. Far more efficient than full-table dumps at scale. Tools: Debezium (open source), Fivetran (managed).

**Message queues (Kafka).** Sit between sources and the ingestion layer. Sources publish events; pipelines consume them. This decouples source from destination: if the pipeline goes down, events queue up and are processed on recovery.

**Reverse ETL.** Sends transformed warehouse data back into operational systems, for example pushing churn scores from Snowflake into Salesforce. Tools: Census, Hightouch.

**Full vs incremental loads.** For large, growing sources (hundreds of GB daily), load only what changed (incremental or CDC) instead of re-extracting everything.

**Paginated APIs.** Handle pagination in a loop, add retries with exponential backoff, and respect rate limits. Avoid firing all requests at once without limits.

---

## 13. Cloud and AWS for data engineering

**Service models**

| Model | You manage | Provider manages | Example |
|---|---|---|---|
| IaaS | OS, runtime, data, apps | Hardware, networking | AWS EC2 |
| PaaS | Data and apps only | Everything below | AWS RDS |
| SaaS | Nothing | Everything | Snowflake |

Modern data stacks are cloud-native: you configure managed services rather than servers.

**Core AWS services**

| Service | What it is | Typical use |
|---|---|---|
| S3 | Object storage, effectively unlimited | Raw landing zone, data lake, Parquet files |
| Glue | Managed ETL + data catalog | Crawl S3 schemas, run managed Spark jobs |
| Athena | Serverless SQL on S3 | Ad-hoc queries on raw data without loading |
| Redshift | AWS columnar MPP data warehouse | Analytics warehouse |
| Lambda | Serverless functions (15-minute max) | Lightweight tasks: API calls, file triggers |
| Kinesis | Streaming service (Streams is Kafka-like; Firehose auto-loads) | Real-time ingestion |
| EventBridge | Event scheduling and routing | Schedule a Lambda at 2 am; trigger on S3 events |
| CloudWatch | Monitoring and logging | Alarms, log queries, observability |

---

## 14. Case study: Dream11

Dream11 is a large fantasy-sports platform. Figures below are as reported in Dream11's engineering write-ups (220M+ users, about 14 TB of data per day, tens of millions of requests per minute at IPL peak).

| Layer | Tool | Concept |
|---|---|---|
| OLTP | AWS Aurora / MySQL | Generation + OLTP storage |
| Batch analytics | Redshift + hourly ETL | Batch ingestion, OLAP warehouse |
| Real-time analytics | Kafka + streaming pipeline | Streaming with low-latency processing |
| Search | AWS OpenSearch | Serving layer |

**Lessons**
- Dream11 runs **both batch and streaming**: batch for historical reporting, streaming for real-time operational decisions
- **The OLTP problem:** they first ran analytics directly on the OLTP database (Aurora) and could not run aggregations at scale. They added a Redshift warehouse with hourly ETL, then found hourly was too stale for some uses, so they added a real-time Kafka pipeline on top
- The story shows OLTP vs OLAP, batch vs streaming and the lifecycle in one production system

---

## 15. The modern data stack

**Old stack:**
```
Source -> [Informatica ETL server] -> on-premise warehouse
```
One vendor, expensive, hard to change.

**Modern stack:**
```
Source -> [Fivetran/Airbyte] -> [S3] -> [Snowflake] -> [dbt] -> [Looker]
         ingestion             storage   warehouse     transform  serving
```
Each tool is replaceable independently.

**Why it won**
- Cloud-native, scales automatically
- Modular: best tool per job
- SQL-first, so analysts and analytics engineers can contribute
- Open-source core (dbt, Airflow and Airbyte are free to run)
- Version-controlled: everything lives in Git

**Full picture**
```
Source systems (OLTP, APIs, SaaS)
        |
Ingestion (Fivetran / Airbyte / custom Python)
        |
Raw storage (S3 / data lake)
        |
Cloud warehouse (Snowflake): raw -> staging -> intermediate -> marts, via dbt
        |
Serving (dashboards / ML / APIs)

Orchestration: Airflow manages all of it
Monitoring:    CloudWatch + DataOps tooling
Security:      IAM + masking + RBAC
```

**Tool landscape**

| Category | Tools |
|---|---|
| Ingestion | Fivetran, Airbyte, Kafka, Debezium |
| Storage | S3, GCS, ADLS |
| Warehouse | Snowflake, BigQuery, Redshift |
| Transformation | dbt, Spark, pandas |
| Orchestration | Airflow, Prefect, Dagster |
| Serving | Looker, Tableau, Power BI |
| Monitoring / quality | Great Expectations, Monte Carlo, Soda |

**Trends:** Snowflake and BigQuery dominate warehousing; dbt is in most modern stacks; Airflow is the most common orchestrator with Dagster and Prefect growing; the lakehouse pattern (Delta Lake, Iceberg) is displacing pure data lakes; streaming is growing but batch still dominates.

---

## 16. dbt

**What it is:** a SQL compiler and DAG runner. You write `SELECT` statements; dbt turns them into tables or views, runs them in dependency order, tests the results and generates documentation.

**What it is not:** dbt does not move data. It only transforms data that is already in the warehouse.

**How it works**
1. You write a SQL model (a `SELECT`)
2. dbt compiles it to `CREATE TABLE/VIEW` and runs it in the warehouse
3. dbt tests the output (nulls, uniqueness, referential integrity)
4. dbt generates a lineage graph

**Layer convention**
```
raw -> staging (stg_)     -> marts (fct_, dim_)
       rename and cast       business logic
```

*Interview answer:* "dbt is the transformation layer in an ELT stack. It takes raw data already in the warehouse, runs SQL transformations in dependency order, tests the outputs and generates lineage documentation. It does not move data."

---

## 17. Apache Airflow

**What it is:** a workflow orchestration tool that defines, schedules, monitors and retries pipelines.

**The problem it solves:** cron runs jobs on a schedule but knows nothing about dependencies. Script 3 still runs if script 1 failed. Airflow adds dependency management, retries, visibility and history.

**DAG (Directed Acyclic Graph)**
- *Directed:* a clear path from start to finish
- *Acyclic:* it never loops back
- *Graph:* tasks and their relationships

```
extract_from_api -> load_to_snowflake -> run_dbt_models -> send_success_alert
```
Each arrow is a dependency. If a task fails, downstream tasks do not run.

**Airflow gives you that cron doesn't:** dependency management, automatic retries, a web UI, full execution history, and backfills.

| Term | Meaning |
|---|---|
| DAG | The whole workflow, written in Python |
| Task | One unit of work |
| Operator | A type of task (Python, Bash, Snowflake) |
| Scheduler | Decides when to trigger DAGs |
| Worker | Executes tasks |
| Web UI | Dashboard for monitoring |

*Interview answer:* "A DAG defines tasks and dependencies in Python. The scheduler triggers it on schedule, and workers run each task in dependency order. Failed tasks retry automatically, and everything is logged in the web UI."

---

## 18. Data security and masking

| Technique | What it does | When to use |
|---|---|---|
| Static masking | Replaces real values with fake ones before storing | Sharing with third parties; dev/test environments |
| Dynamic masking | Real data stays in the warehouse; users see a masked version based on their role | Analyst-facing tables containing PII |
| Tokenisation | Replaces a value with a random token; the real value sits in a secure vault | Payment card data |

**Always mask PII:** names, emails, phone numbers, addresses, payment cards, national IDs, health records, biometric data.

**Rule:** PII never reaches analyst-facing tables unmasked. Build masking into the dbt staging layer.

---

## 19. Self-check questions

Try answering before expanding.

1. What does an analytics engineer ship that a data engineer typically does not?
2. State the grain ("one row represents ...") of each table:
   - `fct_orders`
   - `dim_customer` (SCD Type 2)
   - A daily campaign performance mart

<details>
<summary>Answers</summary>

1. Tested, documented, trusted SQL models (usually dbt models) that turn raw warehouse data into clean, analysis-ready tables. Data engineers ship the pipelines and infrastructure that land the raw data.
2. - `fct_orders`: one order line item (or one order, if that is the grain you chose; state it explicitly)
   - `dim_customer` (SCD2): one version of a customer, meaning one customer during one period in which their attributes were valid
   - Daily campaign mart: one campaign per day

</details>

---

## 20. Further reading

- *Fundamentals of Data Engineering*, Joe Reis and Matt Housley (O'Reilly, 2022). Chapters 1 to 5 cover most of this material in depth.
- dbt documentation: https://docs.getdbt.com
- Apache Airflow documentation: https://airflow.apache.org/docs
- Snowflake documentation: https://docs.snowflake.com
- The Data Warehouse Toolkit, Ralph Kimball and Margy Ross, for dimensional modeling
