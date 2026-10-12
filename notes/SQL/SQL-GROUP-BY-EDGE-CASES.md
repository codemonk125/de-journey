# SQL: GROUP BY Edge Cases and Traps

Master the nuances of grouping, aggregation, and the silent bugs that come with them. These trip up senior engineers.

---

## NULL in GROUP BY

### NULL Groups With NULL

**What it is**: When you GROUP BY a column with NULLs, all NULL values are grouped together into a single group (unlike normal comparison where NULL != NULL).

**Key learning**:
- `GROUP BY status` with 100 NULL values → one group with 100 rows (not 100 separate groups)
- This is special behavior: NULLs are treated as equal for grouping purposes
- Silent bug: "Why is my count off?" → You forgot to handle NULL groups

**Where it shows up**:
- Revenue reports: Orders with NULL customer_id (fraud, invalid data) accidentally grouped together
- Reporting dashboards: Missing categories (NULL tier, NULL region) hidden in one row
- Data quality: Counting groups to find unexpected NULL aggregations

**Example**:

```sql
-- Table: orders
-- customer_id | amount
-- 1           | 100
-- 2           | 50
-- NULL        | 75   (chargeback, unattributed)
-- NULL        | 60   (chargeback, unattributed)
-- 1           | 40

-- GROUP BY customer_id
SELECT customer_id, COUNT(*) as order_count, SUM(amount) as total
FROM orders
GROUP BY customer_id;

-- Result:
-- customer_id | order_count | total
-- 1           | 2           | 140
-- 2           | 1           | 50
-- NULL        | 2           | 135   ← All NULLs grouped together!

-- Common mistake: Assuming each NULL row is a separate group
-- Reality: All NULLs are one group

-- Better: Separate NULL handling
SELECT 
  CASE 
    WHEN customer_id IS NULL THEN 'Unattributed'
    ELSE CAST(customer_id AS VARCHAR)
  END as customer_identifier,
  COUNT(*) as order_count,
  SUM(amount) as total
FROM orders
GROUP BY 
  CASE 
    WHEN customer_id IS NULL THEN 'Unattributed'
    ELSE CAST(customer_id AS VARCHAR)
  END;

-- Result:
-- customer_identifier | order_count | total
-- '1'                 | 2           | 140
-- '2'                 | 1           | 50
-- 'Unattributed'      | 2           | 135   ← Now it's clear
```

**Interview tip**: "Walk me through a GROUP BY query. What happens if one column has NULLs?" → Most don't think about NULL grouping behavior.

---

## Non-Aggregated Columns in SELECT

### PostgreSQL Strict Mode (vs MySQL's Lenient Behavior)

**What it is**: When you SELECT a column that's not in GROUP BY and not aggregated, different databases behave differently.

**Database differences**:
- **PostgreSQL (strict)**: Error — column must be in GROUP BY or an aggregate function
- **MySQL (lenient)**: Returns any value from the group (unpredictable, dangerous)
- **Snowflake (strict)**: Same as PostgreSQL — must be aggregated

**Key learning**:
- PostgreSQL's strictness is a feature, not a bug — it prevents silent data loss
- MySQL's lenient behavior causes production bugs where values seem random
- Always be explicit: include in GROUP BY or wrap in aggregate

**Where it shows up**:
- Migration from MySQL to Snowflake: Queries that worked break
- Lazy coding: Accidentally selecting a non-grouped column, MySQL silently picks one value
- Report debugging: "Why do I see different values each time?" → Ungrouped column with no aggregate

**Example**:

```sql
-- Table: orders
-- order_id | customer_name | amount
-- 1        | Alice         | 100
-- 2        | Alice         | 50
-- 3        | Bob           | 75

-- ❌ PostgreSQL/Snowflake ERROR (correct):
SELECT customer_name, order_id, SUM(amount)
FROM orders
GROUP BY customer_name;
-- ERROR: column "order_id" must appear in the GROUP BY clause or be used in an aggregate function

-- ✅ PostgreSQL/Snowflake (correct):
SELECT customer_name, COUNT(*) as order_count, SUM(amount) as total
FROM orders
GROUP BY customer_name;

-- Result:
-- customer_name | order_count | total
-- Alice         | 2           | 150
-- Bob           | 1           | 75

-- ❌ MySQL SILENTLY PICKS ONE order_id (dangerous):
SELECT customer_name, order_id, SUM(amount)
FROM orders
GROUP BY customer_name;
-- Result (unpredictable):
-- customer_name | order_id | SUM(amount)
-- Alice         | 1        | 150    (or could be 2, depends on MySQL internals)
-- Bob           | 3        | 75

-- ✅ If you need specific order_id (use MAX, MIN, ANY_VALUE):
SELECT 
  customer_name,
  MIN(order_id) as first_order_id,
  MAX(order_id) as last_order_id,
  COUNT(*) as order_count,
  SUM(amount) as total
FROM orders
GROUP BY customer_name;

-- Result:
-- customer_name | first_order_id | last_order_id | order_count | total
-- Alice         | 1              | 2             | 2           | 150
-- Bob           | 3              | 3             | 1           | 75
```

**Interview tip**: "Write a GROUP BY query. Can you include a non-aggregated, non-grouped column?" → If they say yes, they learned on MySQL.

---

## GROUP BY with Expressions

### Column Alias vs Expression Reference

**What it is**: You can GROUP BY a column, an expression, or a column alias. Each behaves differently.

**Tricky cases**:
- `GROUP BY UPPER(name)` — Groups on uppercase version, not original name
- `GROUP BY 1` — Groups on first column in SELECT (positional reference)
- `GROUP BY expression AS alias` — Expression is used, alias name is optional

**Key learning**:
- Positional references (`GROUP BY 1, 2`) are fragile — adding a column breaks the query
- Expressions in GROUP BY must match the SELECT expression exactly (or use aggregate)
- Some databases allow `GROUP BY alias`, others don't (portability issue)

**Where it shows up**:
- Reports with grouped dates: `GROUP BY DATE(created_at)` must match SELECT
- Categorical rollups: `GROUP BY UPPER(status)` to normalize case sensitivity
- Pagination with grouping: Positional references break when columns added

**Example**:

```sql
-- Table: users
-- id | email           | created_at
-- 1  | alice@test.com  | 2024-01-15 10:30:00
-- 2  | ALICE@test.com  | 2024-01-15 14:22:00
-- 3  | bob@test.com    | 2024-01-20 09:15:00

-- ❌ WRONG: Expression in GROUP BY doesn't match SELECT
SELECT 
  email,
  COUNT(*) as login_count
FROM users
GROUP BY LOWER(email);
-- ERROR (Snowflake): column "email" must be used in an aggregate or GROUP BY clause
-- (email ≠ LOWER(email))

-- ✅ CORRECT: Expression matches SELECT
SELECT 
  LOWER(email) as normalized_email,
  COUNT(*) as login_count
FROM users
GROUP BY LOWER(email);

-- Result:
-- normalized_email   | login_count
-- alice@test.com     | 2
-- bob@test.com       | 1

-- ✅ CORRECT: GROUP BY column alias (not portable, but works in PostgreSQL):
SELECT 
  LOWER(email) as normalized_email,
  COUNT(*) as login_count
FROM users
GROUP BY normalized_email;  -- Works in PostgreSQL, not Snowflake

-- ❌ FRAGILE: Positional references
SELECT 
  email,
  COUNT(*) as login_count
FROM users
GROUP BY 1;  -- Groups on first column (email)
-- If someone adds a column before email, this query breaks silently

-- ✅ BETTER: Explicit column reference
SELECT 
  email,
  COUNT(*) as login_count
FROM users
GROUP BY email;

-- ✅ Complex expression: Date truncation
SELECT 
  DATE_TRUNC('month', created_at) as month,
  COUNT(*) as signups
FROM users
GROUP BY DATE_TRUNC('month', created_at);

-- Result:
-- month      | signups
-- 2024-01-01 | 2
-- 2024-01-20 | 1
```

---

## GROUP BY with JOIN (Fan-Out Problem)

### Why JOINs Break Aggregation

**What it is**: When you JOIN a 1-to-many table before GROUP BY, the aggregation multiplies rows.

**Key learning**:
- Join first, group second → Rows already multiplied by join
- Result: Counts, sums are wrong (inflated by fan-out factor)
- Example: One customer with 3 orders, 2 products per order → 6 rows after join, COUNT(*) returns 6 (not 3)

**Where it shows up**:
- Revenue reports: "Why is our total 2x what we expect?" → JOIN before aggregation
- Customer counts: "Why do we have 10,000 customers?" → JOINed to orders, counted wrong
- The #1 SQL bug in production

**Example**:

```sql
-- Table: customers (id: 1, 2)
-- Table: orders (customer_id: 1, 1, 2)
-- Table: order_items (order_id: 1, 1, 1, 2, 2)

-- ❌ WRONG: Join multiplies, then aggregate
SELECT 
  c.customer_id,
  COUNT(*) as item_count
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id;

-- Execution:
-- customers JOIN orders → 1:1 becomes 1:3 (customer 1 gets 2 rows, customer 2 gets 1 row)
-- JOIN order_items → already multiplied rows get multiplied again
-- Result: 1 customer with 2 orders × 3 items = 6 rows (not 3 orders)
-- COUNT(*) = 6 (wrong!)

-- ✅ CORRECT: Aggregate first, then join
SELECT 
  c.customer_id,
  o.item_count
FROM customers c
LEFT JOIN (
  SELECT 
    o.customer_id,
    COUNT(DISTINCT oi.order_item_id) as item_count
  FROM orders o
  LEFT JOIN order_items oi ON o.order_id = oi.order_id
  GROUP BY o.customer_id
) o ON c.customer_id = o.customer_id;

-- Or: Aggregate at each level separately
SELECT 
  c.customer_id,
  SUM(order_totals.item_count) as total_items
FROM customers c
LEFT JOIN (
  SELECT 
    o.customer_id,
    o.order_id,
    COUNT(*) as item_count
  FROM orders o
  LEFT JOIN order_items oi ON o.order_id = oi.order_id
  GROUP BY o.customer_id, o.order_id
) order_totals ON c.customer_id = order_totals.customer_id
GROUP BY c.customer_id;

-- ✅ SIMPLEST: Aggregate distinct at each level
SELECT 
  c.customer_id,
  COUNT(DISTINCT o.order_id) as order_count,
  COUNT(DISTINCT oi.order_item_id) as item_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id;

-- Result:
-- customer_id | order_count | item_count
-- 1           | 2           | 3
-- 2           | 1           | 2
```

**Key pattern**: Use `COUNT(DISTINCT column)` to count distinct entities despite join fan-out.

---

## WHERE vs HAVING

### Execution Order Trap

**What it is**:
- WHERE filters rows BEFORE grouping (before aggregation)
- HAVING filters groups AFTER grouping (after aggregation)

**Key learning**:
- WHERE: Use for row-level filters (id, status, date range)
- HAVING: Use for aggregate filters (SUM > 1000, COUNT > 5)
- WHERE is faster (filters rows before the expensive GROUP BY)
- Cannot use aliases in either (execution order issue from Week 4)

**Where it shows up**:
- Performance tuning: Filter as much as possible in WHERE (before grouping)
- Correctness: Using WHERE for aggregate logic (wrong), using HAVING for row logic (slow)
- Query optimization: WHERE on 1M rows before GROUP BY vs HAVING after GROUP BY (100x difference)

**Example**:

```sql
-- Table: orders
-- order_id | customer_id | status | amount | created_at
-- 1        | 1           | 'completed' | 100 | 2024-01-15
-- 2        | 1           | 'pending'   | 50  | 2024-01-16
-- 3        | 2           | 'completed' | 200 | 2024-01-17
-- 4        | 2           | 'cancelled' | 75  | 2024-01-18

-- ❌ WRONG: Using WHERE for aggregate logic (doesn't work)
SELECT 
  customer_id,
  SUM(amount) as total
FROM orders
WHERE SUM(amount) > 100  -- ERROR! SUM() not available in WHERE
GROUP BY customer_id;

-- ✅ CORRECT: Use HAVING for aggregate filters
SELECT 
  customer_id,
  SUM(amount) as total
FROM orders
GROUP BY customer_id
HAVING SUM(amount) > 100;

-- Result:
-- customer_id | total
-- 1           | 150   (not 100, includes pending)
-- 2           | 275

-- ❌ SLOW: Using HAVING for row-level filters
SELECT 
  customer_id,
  SUM(amount) as total
FROM orders
GROUP BY customer_id
HAVING status = 'completed';  -- This filters groups, not rows
-- Result: Undefined (status is not grouped, HAVING doesn't apply row filters)

-- ✅ FAST: Use WHERE for row-level filters
SELECT 
  customer_id,
  SUM(amount) as total
FROM orders
WHERE status = 'completed'  -- Filter rows BEFORE grouping (fast)
GROUP BY customer_id;

-- Result:
-- customer_id | total
-- 1           | 100   (only completed)
-- 2           | 200   (only completed)

-- ✅ CORRECT: WHERE + HAVING together
SELECT 
  customer_id,
  COUNT(*) as order_count,
  SUM(amount) as total
FROM orders
WHERE created_at >= '2024-01-16'  -- Filter rows first (efficient)
GROUP BY customer_id
HAVING SUM(amount) > 100;  -- Then filter groups (aggregates only)

-- Result:
-- customer_id | order_count | total
-- 1           | 1           | 50   (doesn't meet HAVING threshold, excluded)
-- 2           | 2           | 275
```

**Performance impact**: WHERE on 1M rows before GROUP BY is 100x faster than GROUP BY on 1M rows then HAVING.

---

## GROUP BY All vs GROUP BY Subset

### Aggregate Without Grouping

**What it is**:
- `SELECT COUNT(*), SUM(amount) FROM orders` (no GROUP BY) → 1 row with totals
- `SELECT COUNT(*), SUM(amount) FROM orders GROUP BY customer_id` → N rows (one per customer)

**Key learning**:
- No GROUP BY = aggregate across entire table (1 row result)
- GROUP BY with 0 matches = 0 rows result (not 1 row with NULLs)
- Empty result set vs. NULL aggregates are different

**Where it shows up**:
- Dashboard totals: "Overall revenue" (no grouping)
- Dimension tables with facts: Fact table has 100 customers, dimension query returns 100 rows (one per customer)
- Empty groups: "Products with no sales" requires LEFT JOIN, not GROUP BY alone

**Example**:

```sql
-- Table: orders (no rows where customer_id = 99)
-- order_id | customer_id | amount
-- 1        | 1           | 100
-- 2        | 1           | 50

-- No GROUP BY: Aggregate entire table
SELECT 
  COUNT(*) as total_orders,
  SUM(amount) as total_revenue
FROM orders;

-- Result (1 row):
-- total_orders | total_revenue
-- 2            | 150

-- GROUP BY customer_id: Aggregate per customer
SELECT 
  customer_id,
  COUNT(*) as order_count,
  SUM(amount) as total
FROM orders
GROUP BY customer_id;

-- Result (1 row per customer):
-- customer_id | order_count | total
-- 1           | 2           | 150

-- ❌ GROUP BY with no matches: 0 rows (not 1 row with NULLs)
SELECT 
  customer_id,
  COUNT(*) as order_count
FROM orders
WHERE customer_id = 99  -- No rows match
GROUP BY customer_id;

-- Result (0 rows):
-- (empty result set)

-- ✅ To get empty groups, use a dimension table:
-- Table: customers (id: 1, 2, 3, ...)
-- Table: orders (customer_id: 1, 1)

SELECT 
  c.customer_id,
  c.name,
  COUNT(o.order_id) as order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name;

-- Result:
-- customer_id | name   | order_count
-- 1           | Alice  | 2
-- 2           | Bob    | 0           ← Empty group, not excluded
-- 3           | Carol  | 0           ← Empty group, not excluded
```

---

## Multiple GROUP BY Columns

### Hierarchical Grouping

**What it is**: GROUP BY with multiple columns creates nested groups (region → city → product).

**Key learning**:
- `GROUP BY region, city` → Groups by (region, city) pair
- Grain: What does one row represent? One city in one region with aggregated data
- Order matters: `GROUP BY region, city` ≠ `GROUP BY city, region` (different hierarchy)

**Where it shows up**:
- Sales rollups: Region → District → Store → SKU
- Time series: Year → Month → Day
- Multi-level reporting: Tenant → Account → Transaction

**Example**:

```sql
-- Table: sales
-- region | city    | product | amount
-- NA     | NYC     | Widget  | 100
-- NA     | NYC     | Gadget  | 50
-- NA     | LA      | Widget  | 75
-- EU     | London  | Widget  | 200

-- GROUP BY region, city
SELECT 
  region,
  city,
  COUNT(*) as transactions,
  SUM(amount) as total
FROM sales
GROUP BY region, city;

-- Result (grouped by region-city pairs):
-- region | city   | transactions | total
-- NA     | NYC    | 2            | 150
-- NA     | LA     | 1            | 75
-- EU     | London | 1            | 200

-- GROUP BY region (simpler aggregate)
SELECT 
  region,
  COUNT(*) as transactions,
  SUM(amount) as total
FROM sales
GROUP BY region;

-- Result (grouped by region only):
-- region | transactions | total
-- NA     | 3            | 225
-- EU     | 1            | 200

-- ✅ Multi-level rollup (requires UNION or ROLLUP):
SELECT 
  region,
  city,
  COUNT(*) as transactions,
  SUM(amount) as total
FROM sales
GROUP BY region, city

UNION ALL

SELECT 
  region,
  NULL as city,
  COUNT(*) as transactions,
  SUM(amount) as total
FROM sales
GROUP BY region

UNION ALL

SELECT 
  NULL as region,
  NULL as city,
  COUNT(*) as transactions,
  SUM(amount) as total
FROM sales;

-- Result (hierarchical):
-- region | city   | transactions | total
-- NA     | NYC    | 2            | 150
-- NA     | LA     | 1            | 75
-- NA     | NULL   | 3            | 225   ← Region subtotal
-- EU     | London | 1            | 200
-- EU     | NULL   | 1            | 200   ← Region subtotal
-- NULL   | NULL   | 4            | 425   ← Grand total
```

---

## GROUP BY with ORDER BY

### Sorting Groups

**What it is**: ORDER BY sorts the grouped result (not the input rows). Execution order: GROUP BY first, then ORDER BY.

**Key learning**:
- `GROUP BY customer_id ORDER BY SUM(amount) DESC` → Groups aggregate, then sorted by sum
- Can use aliases in ORDER BY (but not in WHERE/GROUP BY)
- ORDER BY can reference aggregates not in SELECT

**Where it shows up**:
- Top-N reports: "Top 10 customers by revenue"
- Leaderboards: Sorted by score (aggregate)
- Sorted dimensions: Customer list sorted by order count (not creation date)

**Example**:

```sql
-- Table: orders
-- customer_id | amount | order_date
-- 1           | 100    | 2024-01-15
-- 1           | 50     | 2024-01-16
-- 2           | 200    | 2024-01-17

-- ✅ Sort groups by aggregate (SUM)
SELECT 
  customer_id,
  COUNT(*) as order_count,
  SUM(amount) as total
FROM orders
GROUP BY customer_id
ORDER BY SUM(amount) DESC;  -- Sort groups by total spent
-- Alternative: ORDER BY total DESC (using alias)

-- Result:
-- customer_id | order_count | total
-- 2           | 1           | 200
-- 1           | 2           | 150

-- ✅ ORDER BY with expression
SELECT 
  customer_id,
  COUNT(*) as order_count,
  SUM(amount) as total
FROM orders
GROUP BY customer_id
ORDER BY COUNT(*) DESC;  -- Sort by number of orders

-- Result:
-- customer_id | order_count | total
-- 1           | 2           | 150
-- 2           | 1           | 200

-- ✅ ORDER BY aggregate not in SELECT
SELECT 
  customer_id,
  COUNT(*) as order_count
FROM orders
GROUP BY customer_id
ORDER BY SUM(amount) DESC;  -- Sort by sum, even though sum not selected

-- Result:
-- customer_id | order_count
-- 2           | 1           (total 200)
-- 1           | 2           (total 150)
```

---

## GROUP BY with DISTINCT (Redundancy)

### When DISTINCT is Overkill

**What it is**: `SELECT DISTINCT col1, col2 FROM table GROUP BY col1` is redundant.

**Key learning**:
- GROUP BY already returns one row per group
- Adding DISTINCT doesn't change the result
- DISTINCT is useful without GROUP BY (remove duplicates)
- Using both signals confused thinking

**Where it shows up**:
- Junior SQL: "I want distinct groups" → Uses both unnecessarily
- Code review: Spot redundancy

**Example**:

```sql
-- Table: orders
-- customer_id | status | amount
-- 1           | 'completed' | 100
-- 1           | 'completed' | 50
-- 2           | 'pending'   | 75

-- ❌ REDUNDANT: DISTINCT + GROUP BY
SELECT DISTINCT
  customer_id,
  status
FROM orders
GROUP BY customer_id, status;

-- Result (same as without DISTINCT):
-- customer_id | status
-- 1           | 'completed'
-- 2           | 'pending'

-- ✅ CORRECT: GROUP BY alone
SELECT 
  customer_id,
  status
FROM orders
GROUP BY customer_id, status;

-- Result (identical):
-- customer_id | status
-- 1           | 'completed'
-- 2           | 'pending'

-- ✅ DISTINCT without GROUP BY (removes duplicates, different use case)
SELECT DISTINCT
  customer_id,
  status
FROM orders;

-- Result:
-- customer_id | status
-- 1           | 'completed'
-- 2           | 'pending'
-- (no aggregation, just distinct rows)
```

---

## Common GROUP BY Mistakes Summary

| Mistake | Symptom | Fix |
|---------|---------|-----|
| **NULL in GROUP BY** | NULLs grouped together, count off | Use CASE/COALESCE to separate NULL handling |
| **Non-aggregated column** | PostgreSQL error, MySQL picks random value | Add column to GROUP BY or aggregate it |
| **JOIN before GROUP BY** | Counts 2x-10x too high (fan-out) | Use COUNT(DISTINCT) or aggregate before joining |
| **WHERE vs HAVING** | Wrong filter level or slow query | WHERE for rows, HAVING for aggregates |
| **GROUP BY with no matches** | Expecting 1 row with NULLs, get 0 | Use LEFT JOIN to dimension table |
| **Positional references** | Query breaks when columns added | Use explicit column names instead of `GROUP BY 1` |
| **DISTINCT + GROUP BY** | Redundant, confuses intent | Use GROUP BY alone |
| **Forgetting to group** | "Only 1 row when I expected 100" | Add GROUP BY or aggregate everything |

---

## Combined Example: Realistic E-Commerce Report

```sql
-- Scenario: Top customers by revenue, excluding cancelled orders, 
--           showing order count + revenue + avg order size

-- Table: customers (id, name, tier)
-- Table: orders (order_id, customer_id, status, amount)

-- ❌ WRONG APPROACH:
SELECT 
  c.customer_id,
  c.name,
  COUNT(*) as order_count,       -- Counts all orders (including cancelled)
  SUM(o.amount) as total_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'completed'
GROUP BY c.customer_id            -- Missing c.name!
ORDER BY total_revenue DESC
LIMIT 10;
-- ERROR: c.name not in GROUP BY

-- ✅ CORRECT APPROACH:
SELECT 
  c.customer_id,
  c.name,
  COUNT(*) as order_count,        -- Now only completed
  SUM(o.amount) as total_revenue,
  AVG(o.amount) as avg_order_size
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'completed'      -- Filter before grouping (fast)
GROUP BY c.customer_id, c.name    -- All non-aggregated columns included
HAVING COUNT(*) > 1               -- Only customers with 2+ orders
ORDER BY total_revenue DESC       -- Sort by revenue
LIMIT 10;

-- ✅ EVEN BETTER: Handle cancelled orders explicitly
SELECT 
  c.customer_id,
  c.name,
  c.tier,
  COUNT(DISTINCT o.order_id) as completed_order_count,
  SUM(CASE WHEN o.status = 'completed' THEN o.amount ELSE 0 END) as completed_revenue,
  SUM(CASE WHEN o.status = 'cancelled' THEN o.amount ELSE 0 END) as cancelled_revenue,
  COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END) as completed_distinct
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name, c.tier
HAVING COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.order_id END) > 1
ORDER BY completed_revenue DESC
LIMIT 10;
```

---

## Interview Questions

1. **"Write a query to find customers with more than 3 orders. What's the tricky part?"** → NULL grouping, fan-out from JOINs
2. **"Why does this GROUP BY query error in PostgreSQL but worked in MySQL?"** → Non-aggregated column not in GROUP BY
3. **"Our revenue report doubled overnight. What should I check?"** → JOIN before GROUP BY fan-out
4. **"Should I use WHERE or HAVING for this filter?"** → Depends on whether it's row-level or aggregate
5. **"I see NULL as its own group in my report. Is that a bug?"** → No, NULLs group together by design

---

## Next Steps

- **Test every example locally** in PostgreSQL. Run the wrong versions first; watch them fail.
- **Combine with Week 4**: GROUP BY + NULL handling (GROUP BY with NULL columns)
- **Before Week 5**: Practice a 10-table ecommerce GROUP BY scenario (revenue by product by region by quarter)

---

*Last updated: 2026-10-12*
