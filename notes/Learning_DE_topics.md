# Data Engineering Learning Notes

A reference guide for topics explored duri Each entry captures the concept, key insight, production use case, and a concrete example.

---

## SQL & Query Patterns

### CTEs vs Temporary Tables

**What it is**: Two approaches to breaking complex queries into reusable pieces—CTEs (WITH clauses) are inline query blocks, temp tables are materialized to disk/memory.

**Key learning**: CTEs are logical constructs that execute inline each time they're referenced; temp tables are physical materialization that persists for the session. CTEs excel at readability and one-off use. Temp tables win when you reference the same subset 5+ times because they avoid recomputation.

**Where it shows up**: 
- dbt models use CTEs heavily (cleaner, version-controllable, no cleanup needed)
- Airflow ETL tasks use temp tables when doing multiple passes over a filtered dataset to avoid rescanning millions of rows
- Snowflake: CTEs are preferred; temp tables are slower due to storage overhead

**Example**:
```sql
-- CTE approach (readable, one pass)
WITH filtered_orders AS (
  SELECT order_id, customer_id, total
  FROM orders
  WHERE order_date >= '2024-01-01'
),
high_value AS (
  SELECT customer_id, COUNT(*) as order_count
  FROM filtered_orders
  WHERE total > 100
  GROUP BY customer_id
)
SELECT * FROM high_value WHERE order_count > 5;

-- Temp table approach (materialized, reusable)
CREATE TEMP TABLE filtered_orders AS
SELECT order_id, customer_id, total
FROM orders
WHERE order_date >= '2024-01-01';

-- Now query it multiple times without rescanning
SELECT COUNT(*) FROM filtered_orders WHERE total > 100;
SELECT AVG(total) FROM filtered_orders WHERE customer_id = 42;
```

**When to use**:
- CTE: ≤3 references, readable dependency chain, one-off query
- Temp table: ≥4 references, heavy filtering, large dataset, multiple aggregations

---

### COALESCE Pattern

**What it is**: A SQL function that returns the first non-NULL value from a list of columns/expressions. `COALESCE(a, b, c)` returns `a` if not null, else `b` if not null, else `c`.

**Key learning**: COALESCE is your escape hatch for data quality issues—missing delivery dates, no phone numbers, no backup contact. It's not a replacement for data cleaning, but it keeps queries from breaking when sources are incomplete.

**Where it shows up**:
- E-commerce: fallback delivery dates (promised vs actual vs estimated)
- CRM: contact info (mobile → home phone → email)
- Finance: reconciliation (ledger amount → accrual → estimate)
- Fact tables: handling late-arriving dimensions

**Example** (from your notes: `COALESCE(a.deliveryDate, e.deliveredWgcp)`):
```sql
-- Order delivery reconciliation
SELECT 
  order_id,
  customer_id,
  COALESCE(
    a.actual_delivery_date,      -- preferred: actual shipment confirmation
    e.estimated_delivery_date,   -- fallback: carrier estimate
    DATE_ADD(order_date, INTERVAL '7 days')  -- last resort: SLA assumption
  ) AS effective_delivery_date,
  CASE 
    WHEN a.actual_delivery_date IS NOT NULL THEN 'Confirmed'
    WHEN e.estimated_delivery_date IS NOT NULL THEN 'Estimated'
    ELSE 'Assumed'
  END AS delivery_confidence
FROM orders o
LEFT JOIN actual_shipments a ON o.order_id = a.order_id
LEFT JOIN carrier_estimates e ON o.order_id = e.order_id;
```

**Common mistake**: Using COALESCE when you should be fixing upstream data. If 40% of delivery dates are missing, COALESCE masks the problem.

---

## Data Warehousing Features

### Snowflake SQL: QUALIFY and FLATTEN

**What it is**: 
- **QUALIFY**: Filters rows based on window function results (like HAVING for window functions)
- **FLATTEN**: Explodes semi-structured data (JSON, arrays) into rows

**Key learning**: 
- QUALIFY eliminates the need for nested CTEs when ranking/partitioning; you filter on rank directly in the WHERE clause
- FLATTEN is Snowflake's answer to handling JSON—it's the gateway to semi-structured data in your warehouse

**Where it shows up**:
- QUALIFY: Top-N queries (top 5 products per region, recent orders per customer)
- FLATTEN: API responses stored as JSON, event logs with nested properties, AB test variants

**Example**:

```sql
-- QUALIFY: Get top 3 products by sales, per region
SELECT 
  region,
  product_name,
  total_sales,
  RANK() OVER (PARTITION BY region ORDER BY total_sales DESC) as sales_rank
FROM products
QUALIFY sales_rank <= 3;

-- Without QUALIFY, you'd need:
WITH ranked AS (
  SELECT region, product_name, total_sales,
    RANK() OVER (PARTITION BY region ORDER BY total_sales DESC) as sales_rank
  FROM products
)
SELECT * FROM ranked WHERE sales_rank <= 3;
```

```sql
-- FLATTEN: Unpack nested event properties
-- Raw: {"event_type": "purchase", "properties": {"items": [{"sku": "ABC", "qty": 2}]}}
SELECT 
  event_id,
  event_data:event_type as event_type,
  f.value:sku as product_sku,
  f.value:qty as quantity
FROM raw_events,
LATERAL FLATTEN(input => event_data:properties:items) f;

-- Result: One row per item in the purchase
```

---

### Redshift

**What it is**: AWS's columnar data warehouse (OLAP engine). Distributed SQL database optimized for analytical queries over large datasets.

**Key learning**: 
- Redshift is older/simpler than Snowflake; lacks some modern features (no native QUALIFY, FLATTEN)
- It's cheaper at scale for predictable workloads; Snowflake is cheaper for variable workloads
- Redshift shines with deep table joins and aggregations on billion-row tables
- Distribution and sort keys are critical—bad choices destroy performance

**Where it shows up**:
- Legacy enterprises with existing AWS commitments
- Startups doing analytics on massive fact tables (billions of events)
- Teams comfortable tuning distribution/sort keys for performance

**Example** (distribution key matters):
```sql
-- Bad: Redshift will shuffle data across nodes for every join
CREATE TABLE orders (
  order_id INT,
  customer_id INT,
  amount DECIMAL
)
DISTKEY (order_id)  -- each order on a different node
SORTKEY (order_date);

SELECT o.*, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;  -- SLOOOW shuffle

-- Better: Distribute by join key
CREATE TABLE orders (
  order_id INT,
  customer_id INT,
  amount DECIMAL
)
DISTKEY (customer_id)  -- same node as customers table
SORTKEY (order_date);
```

---

### Databricks Photon

**What it is**: Databricks' native vectorized query engine (C++ runtime) that runs SQL faster than standard Spark by avoiding JVM overhead.

**Key learning**: 
- Photon is transparent—enable it and queries run 2-5x faster without code changes
- It's tightly integrated with Delta Lake; if you're on Databricks, you likely get Photon
- Not the same as Spark SQL; it's a lower-level engine underneath

**Where it shows up**:
- Databricks clusters doing heavy analytics on Delta tables
- Teams migrating from Redshift/Snowflake to Databricks—Photon helps bridge performance gaps
- Interactive notebooks and BI dashboards querying large tables

**Example**:
```sql
-- On Databricks with Photon enabled, this runs much faster
SELECT 
  customer_id,
  COUNT(*) as order_count,
  SUM(amount) as total_spent,
  AVG(amount) as avg_order_size
FROM orders
WHERE order_date >= '2024-01-01'
GROUP BY customer_id
HAVING COUNT(*) > 5;

-- Same SQL, but Photon engine handles low-level optimization
```

---

## Data Modeling & Schema Design

### Normalization (Types & Trade-offs)

**What it is**: Organizing table structure to minimize redundancy and dependency issues. There are 5+ normal forms (1NF → 5NF); most production systems target 3NF.

**Key learning**:
- 1NF: No repeating columns (no "phone1, phone2, phone3")
- 2NF: No partial dependencies (non-key fields depend on *all* of primary key, not part of it)
- 3NF: No transitive dependencies (non-key fields don't depend on other non-key fields)
- 4NF/5NF: Handle multi-valued dependencies (rare; used in complex domains like supply chains)
- **Trade-off**: Normalization prevents update anomalies but increases query complexity (more joins)

**Where it shows up**:
- OLTP systems: Normalized to prevent data corruption and update bugs
- OLAP systems: Denormalized (star schema) for query speed; you accept redundancy
- Your capstone: Depends on use case—ecommerce is typically 3NF in transactional DB, denormalized in warehouse

**Example** (Ecommerce):

```sql
-- 1NF violation: Repeating columns
CREATE TABLE customers_bad (
  customer_id INT,
  name VARCHAR,
  phone_1 VARCHAR,
  phone_2 VARCHAR,
  phone_3 VARCHAR
);

-- 1NF: Separate phones into their own table
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  name VARCHAR
);

CREATE TABLE customer_phones (
  customer_id INT,
  phone VARCHAR,
  PRIMARY KEY (customer_id, phone),
  FOREIGN KEY (customer_id) REFERENCES customers
);

-- 2NF violation: Partial dependency
CREATE TABLE orders_bad (
  order_id INT,
  customer_id INT,
  product_id INT,
  product_name VARCHAR,  -- depends on product_id, not composite key
  PRIMARY KEY (order_id, product_id)
);

-- 2NF: Product name lives in products table
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  order_date DATE,
  FOREIGN KEY (customer_id) REFERENCES customers
);

CREATE TABLE order_items (
  order_id INT,
  product_id INT,
  quantity INT,
  price DECIMAL,
  PRIMARY KEY (order_id, product_id),
  FOREIGN KEY (order_id) REFERENCES orders,
  FOREIGN KEY (product_id) REFERENCES products
);

CREATE TABLE products (
  product_id INT PRIMARY KEY,
  name VARCHAR,
  category_id INT
);

-- 3NF violation: Transitive dependency
CREATE TABLE orders_3nf_bad (
  order_id INT PRIMARY KEY,
  customer_id INT,
  city VARCHAR,
  state VARCHAR,
  state_tax_rate DECIMAL  -- depends on state, not on order
);

-- 3NF: State tax lives in states table
CREATE TABLE orders_3nf (
  order_id INT PRIMARY KEY,
  customer_id INT,
  customer_address_id INT
);

CREATE TABLE customer_addresses (
  address_id INT PRIMARY KEY,
  customer_id INT,
  city VARCHAR,
  state_id INT
);

CREATE TABLE states (
  state_id INT PRIMARY KEY,
  state_name VARCHAR,
  tax_rate DECIMAL
);
```

---

### Ecommerce Schema

**What it is**: The data model for an online store—customers, products, orders, inventory, payments, reviews.

**Key learning**: 
- Grain matters: One row in `orders` = one order, not one item
- Use dimensional modeling: fact tables (orders, transactions) + dimension tables (customers, products, dates)
- Soft deletes: Mark deleted products/customers as inactive instead of deleting (preserves history)
- Inventory needs careful handling: track stock at warehouse level, handle oversells

**Where it shows up**:
- Every marketplace, subscription service, retail platform
- Your capstone (likely)

**Example** (Simplified ecommerce star schema):

```sql
-- Fact table: One row per order transaction
CREATE TABLE fact_orders (
  order_id INT PRIMARY KEY,
  customer_sk INT,            -- surrogate key to dim_customers
  product_sk INT,             -- surrogate key to dim_products
  order_date_sk INT,          -- surrogate key to dim_date
  quantity INT,
  unit_price DECIMAL,
  total_amount DECIMAL,
  discount_amount DECIMAL,
  payment_method VARCHAR,
  order_status VARCHAR        -- pending, confirmed, shipped, delivered, cancelled
);

-- Dimension table: Slowly changing dimension for products
CREATE TABLE dim_products (
  product_sk INT PRIMARY KEY,
  product_id INT,
  product_name VARCHAR,
  category VARCHAR,
  subcategory VARCHAR,
  price DECIMAL,
  cost DECIMAL,
  active_flag BOOLEAN,        -- soft delete
  effective_date DATE,
  end_date DATE
);

-- Dimension table: Customers (type 2: track changes)
CREATE TABLE dim_customers (
  customer_sk INT PRIMARY KEY,
  customer_id INT,
  name VARCHAR,
  email VARCHAR,
  country VARCHAR,
  city VARCHAR,
  tier VARCHAR,               -- bronze, silver, gold
  lifetime_value DECIMAL,
  active_flag BOOLEAN,
  effective_date DATE,
  end_date DATE
);

-- Slowly Changing Dimension Example:
-- If customer's tier changes from silver → gold:
-- Old row: customer_id=123, tier='silver', end_date='2024-01-15'
-- New row: customer_id=123, tier='gold', effective_date='2024-01-16', end_date=NULL
```

---

## Data Integration & Pipelines

### Fivetran vs Airbyte

**What it is**:
- **Fivetran**: Managed SaaS data integration. Pre-built connectors, hands-off operation
- **Airbyte**: Open-source + SaaS. DIY-friendly, more control, active community

**Key learning**:
- Fivetran: Pay per GB ingested, handles schema changes, works great if your source is in their catalog
- Airbyte: Free + self-hosted or pay for cloud. Steeper learning curve; you manage more
- Both solve the same problem: Get data from source → warehouse without building custom ETL

**Where it shows up**:
- Fivetran: Enterprise with Salesforce, Jira, HubSpot → Snowflake pipelines
- Airbyte: Startups with custom APIs or sources Fivetran doesn't support

**Comparison table**:

| | Fivetran | Airbyte |
|---|---|---|
| **Cost model** | Per GB ingested (~$1.50/GB) | Open-source (free) + cloud fees |
| **Schema detection** | Automatic + handles changes | Manual config, community helps |
| **Latency** | Depends on connector (5 min to hourly) | Configurable |
| **Support** | Hands-off; Fivetran manages | Community + paid support |
| **When to use** | Salesforce, Hubspot, standard SaaS | Custom APIs, unusual sources, cost-conscious |

---

### Kafka vs Kinesis

**What it is**:
- **Kafka**: Open-source event streaming platform. Self-hosted or managed versions
- **Kinesis**: AWS's managed streaming service. Pay-per-shard model

**Key learning**:
- Kafka: Higher throughput, lower latency, more operational overhead
- Kinesis: Simpler to set up (it's AWS), tightly integrated with Lambda/Glue, pricier at scale
- Both are for real-time data pipelines: IoT sensors, application logs, clickstreams, event sourcing

**Where it shows up**:
- Kafka: High-volume event systems (100k+ events/sec), anywhere you need sub-100ms latency
- Kinesis: AWS-native shops, lower event volumes (< 10k/sec), data lakes using Lake Formation

**Example**:
```python
# Kafka producer pseudocode
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lambda v: json.dumps(v).encode()
)

# Send user events to Kafka topic
event = {
    'user_id': 123,
    'event_type': 'purchase',
    'amount': 49.99,
    'timestamp': '2024-01-15T10:30:00Z'
}
producer.send('user_events', value=event)

# Consumer would subscribe to topic, buffer events, batch to warehouse every 5 min
```

```python
# Kinesis producer pseudocode (AWS SDK)
import boto3
import json

client = boto3.client('kinesis')

event = {
    'user_id': 123,
    'event_type': 'purchase',
    'amount': 49.99
}

client.put_record(
    StreamName='UserEvents',
    Data=json.dumps(event),
    PartitionKey=str(event['user_id'])  # determines shard
)
```

---

## Foundational Concepts

### PostgreSQL: Creating a Database

**What it is**: Setting up a PostgreSQL database—the container for tables, schemas, and users.

**Key learning**:
- Databases are isolated; schemas within a database organize tables logically
- Always create a dedicated user with limited privileges (not postgres superuser)
- Encoding matters: UTF-8 is standard; collation affects sorting

**Where it shows up**:
- Local development; staging/production OLTP systems
- Your capstone if you're prototyping locally before moving to Snowflake

**Example**:
```sql
-- Connect to default postgres database first
psql -U postgres

-- Create a new database
CREATE DATABASE ecommerce_db
  ENCODING 'UTF8'
  LOCALE 'en_US.UTF-8'
  TEMPLATE template0;

-- Create a dedicated user (not superuser)
CREATE USER data_engineer WITH PASSWORD 'secure_password';

-- Grant privileges
GRANT CONNECT ON DATABASE ecommerce_db TO data_engineer;
GRANT CREATE ON DATABASE ecommerce_db TO data_engineer;

-- Connect as the user
psql -U data_engineer -d ecommerce_db

-- Create a schema (organizing logical groups within the database)
CREATE SCHEMA staging;
CREATE SCHEMA marts;

-- Give user access to schemas
GRANT USAGE ON SCHEMA staging TO data_engineer;
GRANT CREATE ON SCHEMA staging TO data_engineer;

-- Now create tables in specific schemas
CREATE TABLE staging.raw_orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  order_date DATE
);

-- Query with schema prefix
SELECT * FROM staging.raw_orders;
```

---

### Big Data & Data Engineering Landscape

**What it is**: The ecosystem of tools for processing, storing, and analyzing data at scale: data lakes, warehouses, stream processors, orchestrators, transformation tools.

**Key learning**:
- **Data Lake**: Cheap storage (S3, ADLS, GCS); schema-on-read; messy but scalable
- **Data Warehouse**: Expensive storage; schema-on-write; organized but less flexible
- **Medallion architecture**: Bronze (raw) → Silver (cleaned) → Gold (analytics)
- **Data engineer's job**: Move data through this pipeline; transform as it flows

**Where it shows up**: Every company with data. Your job will be building and maintaining these pipelines.

**The landscape** (your stack):
- **Storage**: AWS S3 (data lake), Snowflake (warehouse)
- **Ingestion**: Fivetran/Airbyte → S3 or direct to Snowflake
- **Transformation**: dbt (SQL), PySpark (large data), Python (custom logic)
- **Orchestration**: Airflow (Python-native DAGs)
- **Processing**: Spark (distributed), Pandas (local)

---

### Data Architecture & Timestamps

**What it is**: Designing systems for data flow—where does data live, how does it move, when is it refreshed. Timestamps are the glue that ties everything together.

**Key learning**:
- Always use UTC (never local time) in warehouses
- Track three timestamps:
  - `created_at`: When the event happened (business time)
  - `ingested_at`: When the data arrived in the warehouse (pipeline time)
  - `updated_at`: When the record was last changed (data quality check)
- Timezone confusion is a common production bug

**Where it shows up**:
- Fact tables have `event_date` (when it happened) and `ingestion_date` (when it was loaded)
- SLAs are defined on ingestion lag: "All data loaded within 2 hours"
- Data quality checks look for late-arriving data: "Did we get yesterday's events?"

**Example**:
```sql
-- Fact table with three timestamps
CREATE TABLE fact_orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  created_at TIMESTAMP,           -- Eastern time from checkout: 2024-01-15 15:30:00 EST
  amount DECIMAL,
  ingested_at TIMESTAMP,          -- UTC time loaded to warehouse: 2024-01-15 20:31:15 UTC (lag = 61 min)
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Last row update
  _dbt_updated_at TIMESTAMP       -- dbt uses this for incremental loads
);

-- Always compare in UTC to avoid DST/timezone bugs
SELECT 
  order_id,
  created_at AT TIME ZONE 'US/Eastern' as eastern_time,
  ingested_at AT TIME ZONE 'UTC' as utc_time,
  (ingested_at - created_at::TIMESTAMP AT TIME ZONE 'UTC') as ingestion_lag
FROM fact_orders
WHERE DATE(created_at AT TIME ZONE 'US/Eastern') = CURRENT_DATE;

-- Data quality check: Late-arriving orders
SELECT COUNT(*) as late_orders
FROM fact_orders
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '24 hours')
  AND ingested_at > (CURRENT_TIMESTAMP - INTERVAL '2 hours');
```

---

## Next Steps

- **This week**: Build a simple ecommerce schema in PostgreSQL locally
- **Practice**: Write CTEs for 3-4 queries; convert one to a temp table and measure
- **Dig deeper**: Pick one tool (Kafka, Fivetran, or Photon) and build a small example
- **Interview prep**: Be ready to explain normalization without reading this doc

---

*Last updated: 2024-10-12*
