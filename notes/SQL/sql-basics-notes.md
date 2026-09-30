# SQL Week 2: Basics & Introduction



**Table of Contents**
1. [What is SQL & SQL for Data Engineers](#1-what-is-sql--sql-for-data-engineers)
2. [How Databases Work](#2-how-databases-work)
3. [Relational vs NoSQL](#3-relational-vs-nosql)
4. [SQL Data Types & CREATE TABLE](#4-sql-data-types--create-table)
5. [SQL Keywords](#5-sql-keywords)
6. [SELECT & FROM](#6-select--from)
7. [SQL Operators](#7-sql-operators)
8. [WHERE Filtering](#8-where-filtering)
9. [ORDER BY & LIMIT](#9-order-by--limit)
10. [ALTER TABLE](#10-alter-table)
11. [Database Constraints](#11-database-constraints)
12. [Primary Keys, Foreign Keys, Composite Keys](#12-primary-keys-foreign-keys-composite-keys)
13. [INSERT, UPDATE, DELETE](#13-insert-update-delete)
14. [ACID Properties](#14-acid-properties)
15. [Normalization (1NF, 2NF, 3NF)](#15-normalization-1nf-2nf-3nf)
16. [Self-Check Questions](#16-self-check-questions)

---

## 1. What is SQL & SQL for Data Engineers

**SQL** = Structured Query Language. The language for asking questions of relational databases.

**A data engineer writes SQL to:**
- Extract data from source systems
- Validate data quality
- Transform raw data into analytics-ready tables
- Test pipeline outputs
- Diagnose data issues in production

**SQL is not just for queries.** You write DDL (CREATE, ALTER, DROP) to design schemas, and DML (INSERT, UPDATE, DELETE) to load and modify data.

**Why it's non-negotiable:** Every job posting asks for SQL. Every interview includes it. The transformation layer (dbt) is pure SQL. If you can't write it fluently, you can't be a data engineer.

---

## 2. How Databases Work

**A database is a system for storing and retrieving data reliably.**

### Three layers (conceptually)

```
User (your SQL query)
    |
Query Optimizer (figures out the fastest way to run it)
    |
Storage Engine (actually reads/writes files on disk)
    |
Disk (where data lives)
```

### Tables and Rows

A table is a collection of rows. Each row represents one entity.

```
customers table:
┌────────────┬──────────┬───────────┐
│ customer_id│  name    │   city    │
├────────────┼──────────┼───────────┤
│ 1          │ Alice    │ NYC       │
│ 2          │ Bob      │ LA        │
│ 3          │ Carol    │ Chicago   │
└────────────┴──────────┴───────────┘
```

Each column has a name and a **data type** (INTEGER, VARCHAR, DATE, etc.).

### Schemas

A **schema** is a namespace that groups related tables. Think of it as a folder.

```sql
-- Create a table in the "public" schema
CREATE TABLE public.customers (
  customer_id INTEGER,
  name VARCHAR(100)
);

-- Refer to it
SELECT * FROM public.customers;
-- or just
SELECT * FROM customers;  -- if public is the default
```

### Indexes

An **index** is a sorted copy of a column (or columns) that speeds up lookups.

Without an index:
```sql
SELECT * FROM orders WHERE customer_id = 42;
-- Database: scan all 1M rows, check each one
-- Time: slow
```

With an index:
```sql
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
-- Now the database: jump directly to customer_id=42
-- Time: very fast
```

**Cost:** Indexes speed up reads but slow down writes (every INSERT must update the index). Use them on columns you filter or join on frequently.

---

## 3. Relational vs NoSQL

### Relational (SQL)

**What it is:** Data in tables with strict schemas and relationships.

**Examples:** PostgreSQL, MySQL, Snowflake, Redshift.

**Strengths:**
- Schema enforces data quality: a bad row is rejected before it goes in
- Relationships are explicit (foreign keys)
- Queries are predictable and composable
- ACID guarantees (see section 14)

**Weaknesses:**
- Scaling horizontally (across servers) is hard
- Semi-structured data (JSON, arrays) is awkward

### NoSQL (not relational)

**What it is:** Data without a rigid schema. Typically key-value, document, or graph.

**Examples:** MongoDB (document), DynamoDB (key-value), Cassandra (wide-column).

**Strengths:**
- Flexible schema: add a field to one document, not all
- Scales horizontally easily
- Fast for specific access patterns

**Weaknesses:**
- No joins; you do relationships in application code
- No ACID on most systems
- Queries are often system-specific

### In Data Engineering

- **Source systems (OLTP)** are almost always relational (Postgres, MySQL, Oracle)
- **Data warehouses** are relational (Snowflake, Redshift, BigQuery)
- **Data lakes** store files (Parquet, JSON) but query them with SQL engines
- You rarely work with raw NoSQL; if you do, you extract it to JSON/files first

**Mental model:** If it's transactional (orders, payments, accounts), it's relational. If it's logs or events, it may be NoSQL or a message queue (Kafka).

---

## 4. SQL Data Types & CREATE TABLE

### Common Data Types

| Type | What it holds | Example |
|---|---|---|
| INTEGER | Whole numbers | 42, -100 |
| BIGINT | Larger whole numbers | 9223372036854775807 |
| DECIMAL(p,s) | Precise decimals | DECIMAL(10,2) = 12345678.90 |
| FLOAT / DOUBLE | Approximate decimals | 3.14159 (may have rounding errors) |
| VARCHAR(n) | Text, up to n characters | VARCHAR(100) for names |
| TEXT | Unlimited text | Long articles, descriptions |
| DATE | Date only | 2024-01-15 |
| TIMESTAMP | Date and time | 2024-01-15 14:30:00 |
| BOOLEAN | True or false | TRUE, FALSE |
| JSON | Semi-structured data | `{"key": "value"}` |

**In data engineering:**
- Use DECIMAL for money (not FLOAT)
- Use TIMESTAMP with timezone for events
- Use VARCHAR for limited text, TEXT for unlimited
- Use JSON sparingly; usually denormalize first

### CREATE TABLE

```sql
CREATE TABLE orders (
  order_id INTEGER,
  customer_id INTEGER,
  order_date DATE,
  total_amount DECIMAL(10, 2),
  status VARCHAR(20)
);
```

**Every table should have a primary key** (see section 12):

```sql
CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  customer_id INTEGER,
  order_date DATE,
  total_amount DECIMAL(10, 2),
  status VARCHAR(20)
);
```

**Always specify NOT NULL if a field is required:**

```sql
CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  customer_id INTEGER NOT NULL,
  order_date DATE NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending'
);
```

---

## 5. SQL Keywords

SQL has reserved words that have special meaning. Don't name columns or tables after them (or use quotes if you must).

**Common keywords:**
- `SELECT`, `FROM`, `WHERE` — queries
- `INSERT`, `UPDATE`, `DELETE` — modification
- `CREATE`, `ALTER`, `DROP` — schema
- `AND`, `OR`, `NOT` — logic
- `GROUP BY`, `ORDER BY` — grouping and sorting
- `JOIN` — combining tables
- `DISTINCT` — unique values

**What you don't need to memorize:** The full list. Just know they exist and avoid them as names.

---

## 6. SELECT & FROM

**The most basic query:**

```sql
SELECT column1, column2, column3
FROM table_name;
```

**What it does:** Returns all rows from `table_name`, showing only the three columns you listed.

### SELECT *

```sql
SELECT *
FROM customers;
```

**What it does:** Returns all columns. Useful for exploration, but avoided in production (if you add a column later, every query changes behavior).

### SELECT specific columns

```sql
SELECT customer_name, email, phone
FROM customers;
```

**Best practice:** Always list the columns you need. It's faster and clearer.

### Renaming columns with AS

```sql
SELECT customer_name AS name, email AS contact_email
FROM customers;
```

The result has columns named `name` and `contact_email` instead of `customer_name` and `email`.

---

## 7. SQL Operators

### Comparison Operators

| Operator | Meaning | Example |
|---|---|---|
| `=` | Equal | `price = 100` |
| `!=` or `<>` | Not equal | `status != 'pending'` |
| `>` | Greater than | `age > 18` |
| `<` | Less than | `age < 65` |
| `>=` | Greater than or equal | `score >= 80` |
| `<=` | Less than or equal | `salary <= 50000` |

### Logical Operators

| Operator | Meaning | Example |
|---|---|---|
| `AND` | Both conditions true | `age > 18 AND status = 'active'` |
| `OR` | At least one true | `city = 'NYC' OR city = 'LA'` |
| `NOT` | Reverses the condition | `NOT status = 'inactive'` |

### Special Operators

| Operator | Meaning | Example |
|---|---|---|
| `BETWEEN` | Range (inclusive) | `age BETWEEN 18 AND 65` |
| `IN` | Member of a list | `city IN ('NYC', 'LA', 'Chicago')` |
| `LIKE` | Pattern matching | `name LIKE 'A%'` (starts with A) |
| `IS NULL` | Missing value | `phone IS NULL` |
| `IS NOT NULL` | Not missing | `email IS NOT NULL` |

---

## 8. WHERE Filtering

**WHERE** narrows down rows based on a condition.

```sql
SELECT customer_name, email
FROM customers
WHERE age >= 18;
```

**What it does:** Returns customer names and emails only for customers 18 or older.

### Multiple conditions

```sql
SELECT *
FROM orders
WHERE status = 'completed'
  AND total_amount > 100
  AND order_date >= '2024-01-01';
```

**What it does:** Completed orders over $100 placed in 2024 or later.

### Pattern matching with LIKE

```sql
SELECT *
FROM customers
WHERE customer_name LIKE 'A%';
```

**What it does:** Customers whose name starts with 'A'.

- `LIKE 'A%'` — starts with A
- `LIKE '%son'` — ends with 'son' (e.g., Anderson, Wilson)
- `LIKE '%o%'` — contains 'o' anywhere
- `LIKE '_ee%'` — second and third letters are 'ee' (e.g., "beef", "seen")

### IN for multiple values

```sql
SELECT *
FROM customers
WHERE city IN ('NYC', 'LA', 'Chicago');
```

Cleaner than:
```sql
WHERE city = 'NYC' OR city = 'LA' OR city = 'Chicago';
```

---

## 9. ORDER BY & LIMIT

### ORDER BY

Sorts results by a column.

```sql
SELECT customer_name, salary
FROM employees
ORDER BY salary DESC;
```

**What it does:** Lists employees by salary, highest first (DESC = descending).

```sql
ORDER BY salary ASC;  -- Lowest first (ASC is the default)
```

### Multiple sort columns

```sql
SELECT *
FROM employees
ORDER BY department ASC, salary DESC;
```

**What it does:** Sort by department (A-Z), then within each department by salary (highest first).

### LIMIT

Returns only the first N rows.

```sql
SELECT *
FROM employees
ORDER BY salary DESC
LIMIT 10;
```

**What it does:** Top 10 highest-paid employees.

---

## 10. ALTER TABLE

Modifies an existing table schema.

### Add a column

```sql
ALTER TABLE customers
ADD COLUMN phone VARCHAR(20);
```

### Remove a column

```sql
ALTER TABLE customers
DROP COLUMN phone;
```

### Rename a column

```sql
ALTER TABLE customers
RENAME COLUMN phone TO phone_number;
```

### Change a column type

```sql
ALTER TABLE customers
ALTER COLUMN age TYPE BIGINT;
```

**Warning:** Altering production tables is risky. It can fail if data doesn't fit the new type, and it locks the table (briefly) during the change. Test first.

---

## 11. Database Constraints

Constraints enforce rules on data *at the database level*, rejecting bad data before it goes in.

### PRIMARY KEY

Uniquely identifies each row. No two rows can have the same primary key, and it can't be NULL.

```sql
CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY,
  name VARCHAR(100)
);
```

### NOT NULL

A column must always have a value; NULL is not allowed.

```sql
CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  customer_id INTEGER NOT NULL,
  order_date DATE NOT NULL
);
```

### UNIQUE

All values in a column must be unique (but NULL is allowed, and there can be multiple NULLs).

```sql
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY,
  email VARCHAR(100) UNIQUE
);
```

### DEFAULT

If you don't provide a value, use this default.

```sql
CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  status VARCHAR(20) DEFAULT 'pending'
);
```

### CHECK

Values must satisfy a condition.

```sql
CREATE TABLE products (
  product_id INTEGER PRIMARY KEY,
  price DECIMAL(10, 2),
  CHECK (price > 0)
);
```

The database will reject a product with a negative or zero price.

### FOREIGN KEY

Links a column in one table to a primary key in another. Enforces referential integrity.

```sql
CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  customer_id INTEGER,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
```

**What it does:** Every `customer_id` in orders must exist in `customers.customer_id`. You can't add an order for a non-existent customer.

---

## 12. Primary Keys, Foreign Keys, Composite Keys

### Primary Key

A column (or group of columns) that uniquely identifies a row.

```sql
CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100)
);
```

**One row = one customer_id.** You can look up a customer by ID instantly.

### Foreign Key

A column that references a primary key in another table.

```sql
CREATE TABLE orders (
  order_id INTEGER PRIMARY KEY,
  customer_id INTEGER,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
```

**One order points to one customer.** The database enforces this: you can't insert an order with a `customer_id` that doesn't exist in the customers table.

### Composite Key

A primary key made of multiple columns. The combination must be unique.

```sql
CREATE TABLE order_items (
  order_id INTEGER,
  item_number INTEGER,
  product_id INTEGER,
  PRIMARY KEY (order_id, item_number)
);
```

**One row = one (order_id, item_number) pair.** Order 100 can have items 1, 2, 3, but not two item 1s.

---

## 13. INSERT, UPDATE, DELETE

### INSERT

Adds new rows.

```sql
INSERT INTO customers (customer_id, name, email)
VALUES (1, 'Alice', 'alice@example.com');
```

Multiple rows at once:

```sql
INSERT INTO customers (customer_id, name, email)
VALUES 
  (1, 'Alice', 'alice@example.com'),
  (2, 'Bob', 'bob@example.com'),
  (3, 'Carol', 'carol@example.com');
```

### UPDATE

Modifies existing rows.

```sql
UPDATE customers
SET email = 'alice.new@example.com'
WHERE customer_id = 1;
```

**Always use WHERE to specify which rows.** Without it, you update all rows.

```sql
-- WRONG: updates all customers
UPDATE customers
SET status = 'inactive';

-- RIGHT: updates only inactive ones
UPDATE customers
SET status = 'inactive'
WHERE account_age_days > 365;
```

### DELETE

Removes rows.

```sql
DELETE FROM customers
WHERE customer_id = 1;
```

**Again, always use WHERE.** Without it, you delete all rows.

---

## 14. ACID Properties

**ACID** = Atomicity, Consistency, Isolation, Durability. These guarantees make databases trustworthy for transactions.

### Atomicity

A transaction fully completes or fully fails. No partial states.

```sql
-- Transfer $100 from Alice to Bob
BEGIN TRANSACTION;
  UPDATE accounts SET balance = balance - 100 WHERE customer_id = 1;
  UPDATE accounts SET balance = balance + 100 WHERE customer_id = 2;
COMMIT;
```

If the first UPDATE succeeds but the second fails (Bob's account doesn't exist), the whole transaction rolls back. Alice's balance is unchanged. No lost money.

### Consistency

A transaction moves the database from one valid state to another valid state. All constraints are satisfied.

If a FOREIGN KEY constraint says customer_id must exist, the database won't let you insert a row that violates it.

### Isolation

Concurrent transactions don't interfere with each other.

If Alice transfers $100 to Bob while Bob transfers $50 to Alice, the operations don't see half-completed states of each other.

### Durability

Once a transaction commits, it survives crashes. The data is on disk and won't disappear if the server goes down.

### Why it matters in data engineering

Source systems (OLTP databases) enforce ACID rigorously to keep operational data safe. Data warehouses have weaker guarantees but are faster for analytics. Your job: Design idempotent pipelines (safe to re-run) regardless of ACID.

---

## 15. Normalization (1NF, 2NF, 3NF)

**Normalization** = organizing tables to minimize redundancy and prevent anomalies.

### 1NF (First Normal Form)

**Rule:** Every cell contains only one value (atomic).

```
BAD (not 1NF):
customer_id | name  | orders
1           | Alice | [100, 101, 102]  ← array in one cell

GOOD (1NF):
customer_id | name  | order_id
1           | Alice | 100
1           | Alice | 101
1           | Alice | 102
```

### 2NF (Second Normal Form)

**Rule:** Must be 1NF, AND every column must depend on the ENTIRE primary key.

```
BAD (not 2NF):
order_id | customer_id | customer_name | amount
100      | 1           | Alice         | 500

Problem: customer_name depends only on customer_id, not on the full key (order_id).

GOOD (2NF):
orders:
order_id | customer_id | amount
100      | 1           | 500

customers:
customer_id | customer_name
1           | Alice
```

### 3NF (Third Normal Form)

**Rule:** Must be 2NF, AND no column depends on a non-key column.

```
BAD (not 3NF):
customer_id | customer_name | city     | country
1           | Alice         | New York | USA

Problem: country depends on city, not the primary key (customer_id).

GOOD (3NF):
customers:
customer_id | customer_name | city_id
1           | Alice         | 42

cities:
city_id | city     | country
42      | New York | USA
```

### In data engineering

- **OLTP (source systems):** Usually 3NF or close (minimizes redundancy, prevents update anomalies)
- **OLAP (data warehouses):** Often deliberately denormalized (star schema, dimensional modeling) for query speed

Your job: Understand the source system's normalization, then denormalize for analytics.

---

## 16. Self-Check Questions

Try answering before expanding.

1. **What does PRIMARY KEY do? Why do you need it?**

<details>
<summary>Answer</summary>

PRIMARY KEY uniquely identifies each row. It ensures no duplicates and allows fast lookups by key. Without it, you can't reliably find or reference a specific row.
</details>

2. **You have an `orders` table with a `customer_id` column. What constraint would you add to ensure every order has a customer that exists in the `customers` table?**

<details>
<summary>Answer</summary>

A FOREIGN KEY:
```sql
ALTER TABLE orders
ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
```
</details>

3. **Write a query to find all customers who live in NYC, LA, or Chicago, ordered by name.**

<details>
<summary>Answer</summary>

```sql
SELECT *
FROM customers
WHERE city IN ('NYC', 'LA', 'Chicago')
ORDER BY customer_name ASC;
```
</details>

4. **What's the difference between LIKE 'A%' and LIKE '%A%'?**

<details>
<summary>Answer</summary>

- `LIKE 'A%'` matches strings that START with A (Alice, Andrew, Antonio)
- `LIKE '%A%'` matches strings that contain A ANYWHERE (Alice, Carol, Nathan)
</details>

5. **You accidentally wrote `UPDATE customers SET status = 'inactive';` without a WHERE clause. What happened, and how do you prevent it?**

<details>
<summary>Answer</summary>

Every customer got marked as inactive. Prevention: Always write WHERE first, test the SELECT, then convert to UPDATE/DELETE. Or use transactions: BEGIN, run the UPDATE, check with SELECT, then COMMIT only if correct.
</details>

---

## Key Takeaways

1. **Data types matter.** Use DECIMAL for money, not FLOAT. TIMESTAMP with timezone for events.
2. **Constraints are your friend.** NOT NULL, PRIMARY KEY, and FOREIGN KEY catch bad data at the database level.
3. **Always use WHERE.** UPDATE and DELETE without WHERE are disasters.
4. **Sort then LIMIT.** If you want the top 10, sort first.
5. **Plan to denormalize later.** Source systems are normalized; analytics denormalizes for speed.

---

## Next Steps

- Write 5 queries on a sample dataset (iPhone sales, customer orders)
- Practice each operator: =, !=, BETWEEN, IN, LIKE
- Solve the first 5 DataLemur problems (customer filtering, aggregation, LIKE patterns)
- Week 3: JOINs, GROUP BY, and combining tables
