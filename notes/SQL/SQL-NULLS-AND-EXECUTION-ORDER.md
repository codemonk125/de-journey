# SQL: NULLs, Execution Order, and Common Gotchas

Critical SQL patterns for handling NULL values and understanding query execution order. These are interview questions and common production bugs.

---

## NULL Fundamentals

### The Three-Valued Logic of NULL

**What it is**: In SQL, NULL is not "empty" or "zero"—it's *unknown*. Any comparison with NULL returns NULL (not TRUE or FALSE), which is treated as FALSE in WHERE clauses.

**Key learning**:
- `NULL = NULL` → NULL (not TRUE)
- `NULL != NULL` → NULL (not TRUE)
- `5 > NULL` → NULL (not TRUE or FALSE)
- `WHERE NULL` → Row is excluded
- `WHERE NOT NULL` → Row is excluded

This is why `WHERE status = 'active'` silently excludes rows where `status IS NULL`.

**Where it shows up**:
- Data quality bugs: "Why are we missing 30% of orders?" (They have NULL status)
- Migrations: Old data has NULLs; new code assumes filled columns
- LEFT JOINs: Right side columns are NULL for non-matching rows

**Example**:
```sql
-- Table: orders
-- order_id | status
-- 1        | 'completed'
-- 2        | 'pending'
-- 3        | NULL
-- 4        | 'cancelled'

-- This query returns only rows 1, 2, 4 (NOT row 3!)
SELECT * FROM orders
WHERE status != 'cancelled';

-- To include NULL rows, you must explicitly check:
SELECT * FROM orders
WHERE status != 'cancelled' OR status IS NULL;

-- Or safer: use COALESCE
SELECT * FROM orders
WHERE COALESCE(status, 'unknown') != 'cancelled';
```

---

## NOT IN vs NOT EXISTS (NULL Handling)

### Why NOT EXISTS is Better

**What it is**:
- `NOT IN`: Checks if a value is not in a list. Broken by NULL.
- `NOT EXISTS`: Checks if a subquery returns zero rows. Handles NULL correctly.

**Key learning**: 
- `NOT IN (1, 2, NULL)` → Always returns FALSE (even for values not in list), because NULL breaks the logic
- `NOT EXISTS` works the same whether the subquery returns NULL or not (it just checks if rows exist)
- This is a *gotcha* that trips up many SQL engineers

**Where it shows up**:
- Membership queries: "Give me customers with no orders"
- Exclusion logic: "List products not in a specific category"
- Data validation: "Find records without a match in the reference table"

**Example** (The Bug):

```sql
-- Table: customers (id: 1, 2, 3)
-- Table: recent_orders (customer_id: 1, 2, NULL)

-- ❌ WRONG: This returns NO rows (because of NULL)
SELECT * FROM customers
WHERE id NOT IN (
  SELECT customer_id FROM recent_orders
);
-- Returns: (empty set)
-- Why? NOT IN with NULL always evaluates to FALSE

-- Proof:
-- id=1: 1 NOT IN (1, 2, NULL) → FALSE (1 is in the list)
-- id=2: 2 NOT IN (1, 2, NULL) → FALSE (2 is in the list)
-- id=3: 3 NOT IN (1, 2, NULL) → NULL (3 is not in {1,2}, but NULL breaks it)
--       NULL is treated as FALSE in WHERE clause

-- ✅ CORRECT: Use NOT EXISTS
SELECT * FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM recent_orders r
  WHERE r.customer_id = c.id
);
-- Returns: id=3 (the only customer with no orders)

-- Alternative (if you're sure subquery has no NULLs):
SELECT * FROM customers
WHERE id NOT IN (
  SELECT customer_id FROM recent_orders
  WHERE customer_id IS NOT NULL  -- Explicitly exclude NULLs
);
```

**When to use**:
- NOT EXISTS: Always (it's safer and handles NULLs)
- NOT IN: Only if you're certain the subquery has no NULLs

---

## NULL in ORDER BY

### Where NULLs Sort

**What it is**: Different databases sort NULLs differently. PostgreSQL, MySQL, and Snowflake all put NULLs at different positions by default.

**Key learning**:
- PostgreSQL: NULLs appear FIRST in ASC, LAST in DESC (default)
- MySQL: NULLs appear FIRST in ASC, FIRST in DESC (different!)
- Snowflake: Configurable with `NULLS FIRST | NULLS LAST`
- Always be explicit about NULL placement if it matters

**Where it shows up**:
- Leaderboards: "Top 10 players" with NULL scores—do NULLs come first or last?
- Timestamped data: Last-modified times with NULLs for "never modified"
- Reporting: Sorting sales by amount with NULLs for missing data

**Example** (PostgreSQL):

```sql
-- Table: sales
-- salesperson | amount
-- Alice       | 1000
-- Bob         | 500
-- Charlie     | NULL
-- Diana       | 750

-- Default ASC: NULLs FIRST, then sorted
SELECT * FROM sales
ORDER BY amount ASC;
-- Result:
-- Charlie     | NULL      (NULL appears FIRST)
-- Bob         | 500
-- Diana       | 750
-- Alice       | 1000

-- Default DESC: sorted, then NULLs LAST
SELECT * FROM sales
ORDER BY amount DESC;
-- Result:
-- Alice       | 1000
-- Diana       | 750
-- Bob         | 500
-- Charlie     | NULL      (NULL appears LAST)

-- Explicit control (PostgreSQL 8.3+):
SELECT * FROM sales
ORDER BY amount DESC NULLS FIRST;
-- Result:
-- Charlie     | NULL      (forced to the front)
-- Alice       | 1000
-- Diana       | 750
-- Bob         | 500

-- Portable solution (works everywhere):
SELECT * FROM sales
ORDER BY amount IS NULL DESC, amount DESC;
-- TRUE sorts after FALSE, so NULLs come first
-- Result: Charlie (NULL), Alice, Diana, Bob
```

---

## ORDER BY, LIMIT, and Randomness

### Why LIMIT Without ORDER BY is Dangerous

**What it is**: 
- `LIMIT` alone does NOT guarantee consistent results across runs
- Without `ORDER BY`, the database can return rows in any order
- `ORDER BY` provides a guaranteed sort before `LIMIT` applies

**Key learning**:
- `SELECT * FROM table LIMIT 10` → Arbitrary 10 rows (may differ between runs)
- `SELECT * FROM table ORDER BY id LIMIT 10` → Consistent: rows 1-10 by ID
- `LIMIT` without `ORDER BY` is fine for "any N rows" but dangerous for "first N"
- This causes flaky tests, inconsistent reports, and hard-to-debug production bugs

**Where it shows up**:
- Pagination: "Show me rows 1-10" requires `ORDER BY`
- Sampling: "Give me 100 random rows" (intentional randomness)
- Top-N queries: "Top 5 products by sales" requires `ORDER BY`

**Example**:

```sql
-- ❌ WRONG: No guaranteed order, may return different rows each run
SELECT * FROM orders
LIMIT 10;
-- Run 1 might return: orders 5, 1, 100, 42, ...
-- Run 2 might return: orders 8, 3, 50, 15, ... (different!)

-- ✅ CORRECT: Guaranteed consistent results
SELECT * FROM orders
ORDER BY order_id
LIMIT 10;
-- Always returns: orders 1, 2, 3, ..., 10

-- ✅ Intentional randomness (explicit):
SELECT * FROM orders
ORDER BY RANDOM()
LIMIT 10;
-- Returns 10 random orders (shuffled each run, but we're explicit about it)

-- ✅ Pagination (must have ORDER BY):
SELECT * FROM orders
ORDER BY order_date DESC
LIMIT 10 OFFSET 20;
-- Guaranteed: rows 21-30 when sorted by order_date DESC
-- Without ORDER BY, pagination would be meaningless
```

**Interview tip**: "Why should you always use ORDER BY with LIMIT?" → Show that without it, results are non-deterministic.

---

## SQL Query Execution Order

### Why You Can't Use Aliases in WHERE

**What it is**: SQL queries don't execute in the order they're written. The actual execution order is:

1. **FROM** — Identify the table(s)
2. **WHERE** — Filter rows (aliases NOT available yet)
3. **GROUP BY** — Group rows
4. **HAVING** — Filter groups (aliases NOT available)
5. **SELECT** — Choose columns (aliases created here)
6. **ORDER BY** — Sort results (aliases ARE available here)
7. **LIMIT** — Take first N rows

**Key learning**:
- WHERE executes BEFORE SELECT, so column aliases don't exist in WHERE
- ORDER BY executes AFTER SELECT, so aliases ARE available there
- This is why `WHERE total > 100` works, but `WHERE subtotal + tax > 100` requires a full expression
- HAVING is for filtered groups; WHERE is for filtered rows

**Where it shows up**:
- Common error: `WHERE order_total > 100` when you meant `WHERE quantity * price > 100`
- Query optimization: Filtering in WHERE is faster than filtering in HAVING
- Subqueries: Sometimes necessary to work around execution order limitations

**Example** (The Error):

```sql
-- ❌ WRONG: Column alias doesn't exist yet in WHERE
SELECT 
  customer_id,
  quantity * price AS total
FROM orders
WHERE total > 100;  -- ERROR! total alias doesn't exist in WHERE

-- ✅ CORRECT: Repeat the expression or use subquery
SELECT 
  customer_id,
  quantity * price AS total
FROM orders
WHERE quantity * price > 100;

-- ✅ CORRECT: Use a subquery (WHERE can't see aliases)
SELECT * FROM (
  SELECT 
    customer_id,
    quantity * price AS total
  FROM orders
) subquery
WHERE total > 100;

-- ✅ CORRECT: Alias works in ORDER BY (happens after SELECT)
SELECT 
  customer_id,
  quantity * price AS total
FROM orders
WHERE quantity * price > 100  -- Filter first
ORDER BY total DESC;  -- ORDER BY sees the alias

-- ✅ CORRECT: HAVING for grouped data
SELECT 
  customer_id,
  SUM(quantity * price) AS total_spent
FROM orders
GROUP BY customer_id
HAVING SUM(quantity * price) > 100;  -- HAVING for groups
```

---

## Combining Concepts: A Realistic Example

**Scenario**: "Find all customers who placed more than 3 orders, excluding orders with NULL status, sorted by name, return top 5"

```sql
-- Without understanding these concepts, this query breaks:

-- ❌ Common mistakes:
-- 1. Using NOT IN with NULL
-- 2. Forgetting to exclude NULL orders
-- 3. No ORDER BY before LIMIT (random results)
-- 4. Trying to use an alias in WHERE

-- ✅ Correct approach:
SELECT 
  c.customer_id,
  c.name,
  COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status IS NOT NULL  -- Exclude NULLs
GROUP BY c.customer_id, c.name
HAVING COUNT(o.order_id) > 3  -- Filter groups (after COUNT)
ORDER BY c.name ASC  -- Deterministic sort
LIMIT 5;  -- Top 5 (now consistent)

-- Explanation of execution:
-- 1. FROM/JOIN: Get customers and their orders
-- 2. WHERE: Exclude rows where order status is NULL
-- 3. GROUP BY: Aggregate per customer
-- 4. HAVING: Filter groups with >3 orders
-- 5. SELECT: Create result columns (order_count alias)
-- 6. ORDER BY: Sort by name (alias works here)
-- 7. LIMIT: Take first 5
```

---

## Quick Reference: Common NULL Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| `WHERE status != 'active'` | Excludes NULLs | `WHERE status != 'active' OR status IS NULL` |
| `WHERE id NOT IN (subquery)` | Breaks if subquery has NULL | Use `NOT EXISTS` instead |
| `LIMIT 10` (no ORDER BY) | Non-deterministic results | Add `ORDER BY id` |
| `WHERE alias > 100` | Alias doesn't exist yet | Use the full expression |
| `ORDER BY amount` on mixed NULLs | Different per database | Use `NULLS FIRST` or `NULLS LAST` |
| `SELECT col WHERE col IS NULL` | Returns empty (NULL != NULL) | Use `IS NULL`, not `= NULL` |

---

## Next Steps

- **Run every example locally** in PostgreSQL. Don't just read them.
- **Test**: Create a table with NULLs, run the NOT IN example, see it break.
- **Refactor one old query** you've written: Find any `NOT IN` and convert to `NOT EXISTS`.
- **Interview practice**: "Explain why you can't use aliases in WHERE but can in ORDER BY."

---

*Last updated: 2024-10-12*
