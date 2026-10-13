# SQL JOINs: Learning Guide

## The Core Concept: Cardinality

When you join two tables, the output row count depends on matching keys:

**Rule:**  
`1 row on left × N matching rows on right = N output rows`

This is why joins can explode or shrink your data unexpectedly.

---

## Join Types & When to Use Them

### 1. INNER JOIN
**What it does:** Returns only rows where the key exists in BOTH tables.

**Grain:** One row = one matching pair from left and right.

**Use case:** "Show me orders WITH their customer details."

```sql
SELECT 
    o.order_id,
    o.amount,
    c.customer_name
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id;
```

**Danger:** If the RIGHT table has duplicate keys, your data explodes.  
Example: Customer 101 appears twice in customers table → each order for customer 101 matches twice.

---

### 2. LEFT JOIN
**What it does:** Returns ALL rows from the left table + matching rows from right. Non-matching right rows are NULL.

**Grain:** One row = one left table row (possibly with NULL on the right).

**Use case:** "Show me ALL customers and their orders (even customers who never ordered)."

```sql
SELECT 
    c.customer_id,
    c.customer_name,
    o.order_id,
    o.amount
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id;
```

---

### 3. Finding Missing Data (LEFT JOIN + WHERE NULL)
**The pattern:** LEFT JOIN + filter for NULL values on the right table.

**Grain:** One row = one left table row with no match on the right.

**Use case:** "Show me customers WHO HAVE NOT placed any orders."

```sql
SELECT 
    c.customer_id,
    c.customer_name
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
WHERE o.customer_id IS NULL;
```

**Why this works:**
- LEFT JOIN brings in all customers.
- Customers without orders get NULL in all order columns.
- WHERE filters for those NULLs.

**Alternative (more readable for some):**
```sql
SELECT *
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
);
```

---

## The Cardinality Explosion Problem

### Real Example: Revenue Duplication

**Sales Table (clean):**
```
customer_id | revenue
101         | 100
102         | 200
```
Total: 300

**Customers Table (has duplicates!):**
```
customer_id | segment
101         | Gold
101         | Premium  ← Duplicate!
102         | Silver
```

**Query:**
```sql
SELECT 
    s.customer_id,
    s.revenue,
    c.segment
FROM sales s
INNER JOIN customers c
    ON s.customer_id = c.customer_id;
```

**Result:**
```
customer_id | revenue | segment
101         | 100     | Gold
101         | 100     | Premium  ← OOPS: revenue counted twice!
102         | 200     | Silver
```
Total: 400 (but should be 300!)

**Why?** Customer 101 appears twice on the right, so the sales row for 101 matches twice.

### How Data Engineers Detect This

**Step 1: Count before join**
```sql
SELECT COUNT(*) FROM sales;
```
Result: 2 rows

**Step 2: Count after join**
```sql
SELECT COUNT(*)
FROM sales s
INNER JOIN customers c
    ON s.customer_id = c.customer_id;
```
Result: 3 rows

**If they don't match, you have duplicate keys!**

**Step 3: Find the duplicates**
```sql
SELECT 
    customer_id,
    COUNT(*) as count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

**Step 4: Validate business metrics**
```sql
SELECT SUM(revenue) FROM sales;           -- Should be 300
SELECT SUM(revenue) FROM sales s
INNER JOIN customers c
    ON s.customer_id = c.customer_id;     -- Check if still 300
```

---

## NULL Handling in Joins

### NULL in Join Keys
**Problem:** Rows with NULL keys never match (in SQL, NULL ≠ NULL).

```sql
SELECT *
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id;
```

If a customer has `customer_id = NULL`, it will NOT match any orders, even if an order also has `customer_id = NULL`.

### Checking for NULL Keys Before Joining
```sql
SELECT COUNT(*)
FROM customers
WHERE customer_id IS NULL;

SELECT COUNT(*)
FROM orders
WHERE customer_id IS NULL;
```

If either has NULLs, those rows will be lost in an INNER JOIN.

### NULL Sorting Behavior (Database-Specific)

**PostgreSQL:**
```
ASC → NULLs last
DESC → NULLs first
```

**MySQL:**
```
ASC → NULLs first
DESC → NULLs last
```

**PostgreSQL explicit control:**
```sql
SELECT * FROM customers
ORDER BY created_date DESC NULLS FIRST;  -- PostgreSQL only
```

---

## Self-Joins: Joining a Table to Itself

### Use Case: Manager-Employee Relationships

**Employees Table:**
```
employee_id | employee_name | manager_id
1           | Alice         | NULL
2           | Bob           | 1
3           | Charlie       | 1
```

**Query: Show each employee and their manager's name**
```sql
SELECT 
    e.employee_id,
    e.employee_name,
    m.employee_name AS manager_name
FROM employees e
LEFT JOIN employees m
    ON e.manager_id = m.employee_id;
```

**Result:**
```
employee_id | employee_name | manager_name
1           | Alice         | NULL          ← No manager (CEO)
2           | Bob           | Alice
3           | Charlie       | Alice
```

**Grain:** One row = one employee (with their manager info, if it exists).

---

## Production Checklist Before Joining

1. **Check NULL keys** — Do either table have NULL in the join key?
   ```sql
   SELECT COUNT(*) FROM table1 WHERE key IS NULL;
   ```

2. **Find duplicate keys** — Does the join key have duplicates?
   ```sql
   SELECT key, COUNT(*) FROM table1 GROUP BY key HAVING COUNT(*) > 1;
   ```

3. **Count rows before and after** — Do they match?
   ```sql
   SELECT COUNT(*) FROM t1;
   SELECT COUNT(*) FROM t1 JOIN t2 ON ...;
   ```

4. **Validate business metrics** — Does revenue, count, or key aggregates make sense?
   ```sql
   SELECT SUM(amount) FROM t1;
   SELECT SUM(amount) FROM t1 JOIN t2 ON ...;
   ```

5. **Verify join key uniqueness** — What should be unique? (Often the key on one side should be unique)
   ```sql
   SELECT key, COUNT(*) FROM customers GROUP BY key;
   ```

---

## Interview Answers You Should Know

**Q: "A query's row count jumped from 10k to 150k after an INNER JOIN. What happened?"**
A: "Likely duplicate keys on the right side of the join. For every left row that had 15 matches on the right, the output multiplied. I'd check for duplicates with `GROUP BY key HAVING COUNT(*) > 1` on the joined table."

**Q: "How do you find customers who never placed orders?"**
A: "LEFT JOIN customers to orders, then filter for NULL: `WHERE orders.order_id IS NULL`."

**Q: "Revenue increased after a join. Why?"**
A: "Duplicate keys on the joined table multiplied the revenue. Each left row matched multiple right rows, inflating the total."

**Q: "What's the difference between INNER JOIN and LEFT JOIN?"**
A: "INNER keeps only matching rows. LEFT keeps all left rows and fills non-matches with NULL on the right."
