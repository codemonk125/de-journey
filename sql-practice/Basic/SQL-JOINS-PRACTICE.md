# SQL JOINs: Practice Exercises with Solutions

## Exercise 1: Basic INNER JOIN
**Problem:** Attach customer names to orders. Return order_id, customer_name, and amount. Sort by order_id.

**Tables:**
```
orders:
order_id | customer_id | amount
1        | 101         | 50.00
2        | 102         | 75.00
3        | 101         | 120.00

customers:
customer_id | name
101         | Alice
102         | Bob
103         | Charlie
```

**Grain:** One row = one order with its customer's name.

**Your Solution:**
```sql
-- Write your query here
```

**✓ Solution:**
```sql
SELECT 
    o.order_id,
    c.name AS customer_name,
    o.amount
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
ORDER BY o.order_id;
```

**Expected Output:**
```
order_id | customer_name | amount
1        | Alice         | 50.00
2        | Bob           | 75.00
3        | Alice         | 120.00
```

**Why this works:**
- INNER JOIN returns only orders that have matching customers.
- We alias tables (o, c) for readability.
- We sort by order_id as required.
- Grain is preserved: one row per order.

---

## Exercise 2: LEFT JOIN with All Customers
**Problem:** Show ALL customers and their orders (even if they haven't ordered). Return customer_id, customer_name, order_id, and amount. Sort by customer_id.

**Tables:** Same as Exercise 1

**Grain:** One row = one customer (possibly matched with an order, or NULL if no order).

**Your Solution:**
```sql
-- Write your query here
```

**✓ Solution:**
```sql
SELECT 
    c.customer_id,
    c.name AS customer_name,
    o.order_id,
    o.amount
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
ORDER BY c.customer_id;
```

**Expected Output:**
```
customer_id | customer_name | order_id | amount
101         | Alice         | 1        | 50.00
101         | Alice         | 3        | 120.00
102         | Bob           | 2        | 75.00
103         | Charlie       | NULL     | NULL
```

**Why this works:**
- LEFT JOIN keeps all customers (left table).
- Charlie has no orders, so order_id and amount are NULL.
- Notice Alice appears twice (she has 2 orders).
- Grain: one row per (customer, order) pair.

**Key Insight:** Row count is 4, not 3. This is because Alice appears twice. Always check cardinality!

---

## Exercise 3: Finding Missing Data (Customers WITHOUT Orders)
**Problem:** Find customers who have NEVER placed an order. Return customer_id and customer_name.

**Tables:** Same as Exercise 1

**Grain:** One row = one customer who has NO matching orders.

**Your Solution:**
```sql
-- Write your query here
```

**✓ Solution:**
```sql
SELECT 
    c.customer_id,
    c.name AS customer_name
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
WHERE o.customer_id IS NULL;
```

**Expected Output:**
```
customer_id | customer_name
103         | Charlie
```

**Alternative Solution (using NOT EXISTS):**
```sql
SELECT 
    c.customer_id,
    c.name AS customer_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
);
```

**Why this works:**
- LEFT JOIN brings in all customers.
- Customers with orders get order_id filled in; customers without orders get NULL.
- WHERE filters for rows where order_id is NULL (no match found).
- Result: only customers with no orders.

---

## Exercise 4: Cardinality Explosion Detection
**Problem:** You're joining sales to a sales_rep table. Before the join, sales has 1000 rows. After the join, it has 1500 rows. What happened? Write a query to find the problem.

**Tables:**
```
sales:
sale_id | rep_id | amount
1       | 101    | 100
2       | 101    | 200
3       | 102    | 150
... (1000 rows total)

sales_reps:
rep_id | name
101    | Alice
101    | Alice (duplicate?!)
102    | Bob
... (problem here!)
```

**Grain:** After joining, you expect 1000 rows (one per sale). But you got 1500.

**Your Solution:**
```sql
-- Write a query to find which rep_ids have duplicates
```

**✓ Solution:**
```sql
SELECT 
    rep_id,
    COUNT(*) as count
FROM sales_reps
GROUP BY rep_id
HAVING COUNT(*) > 1
ORDER BY count DESC;
```

**Expected Output:**
```
rep_id | count
101    | 2       ← Alice appears twice!
```

**Follow-up: Verify the cardinality explosion**
```sql
SELECT COUNT(*) FROM sales;                           -- Should be 1000
SELECT COUNT(*) FROM sales s
INNER JOIN sales_reps sr ON s.rep_id = sr.rep_id;   -- Returns 1500 (WRONG!)
```

**Why:** Sales_rep 101 (Alice) appears twice in sales_reps. Each of the sales rows for rep 101 matches twice, doubling the count for those rows.

**Fix Options:**
1. Remove the duplicate from sales_reps.
2. Use a subquery to get distinct reps first.
3. Use a window function to deduplicate.

---

## Exercise 5: Self-Join (Manager-Employee)
**Problem:** Show each employee and their manager's name. Include employees with no manager (CEO). Sort by employee_id.

**Tables:**
```
employees:
employee_id | name    | manager_id
1           | Alice   | NULL
2           | Bob     | 1
3           | Charlie | 1
4           | Diana   | 2
```

**Grain:** One row = one employee (with manager info if available).

**Your Solution:**
```sql
-- Write your query here
```

**✓ Solution:**
```sql
SELECT 
    e.employee_id,
    e.name AS employee_name,
    m.name AS manager_name
FROM employees e
LEFT JOIN employees m
    ON e.manager_id = m.employee_id
ORDER BY e.employee_id;
```

**Expected Output:**
```
employee_id | employee_name | manager_name
1           | Alice         | NULL
2           | Bob           | Alice
3           | Charlie       | Alice
4           | Diana         | Bob
```

**Why this works:**
- You join employees to itself (aliased as e and m).
- e.manager_id links to m.employee_id.
- LEFT JOIN handles Alice (manager_id = NULL).
- Grain: one row per employee.

---

## Exercise 6: Detecting NULL Keys Before Joining
**Problem:** Before you join, check if either table has NULL in the join key. Write two queries.

**Tables:** Same as Exercise 1 (but imagine some NULLs exist)

**Your Solution:**
```sql
-- Query 1: Check for NULLs in orders
-- Query 2: Check for NULLs in customers
```

**✓ Solution:**
```sql
-- Check orders table
SELECT COUNT(*) as null_count
FROM orders
WHERE customer_id IS NULL;

-- Check customers table
SELECT COUNT(*) as null_count
FROM customers
WHERE customer_id IS NULL;
```

**Why this matters:**
- If either returns > 0, those rows will NOT match in a join.
- In an INNER JOIN, they disappear entirely.
- In a LEFT JOIN, they remain but with NULL on the right side.
- If you're missing expected data after a join, NULLs in the key are often the culprit.

---

## Exercise 7: Validating Join Results (Revenue Check)
**Problem:** You're joining orders to customers. Before the join, the total revenue is 1000. After the join, it's 1200. What went wrong?

**Tables:**
```
orders:
order_id | customer_id | revenue
1        | 101         | 300
2        | 102         | 400
3        | 103         | 300

customers:
customer_id | name
101         | Alice
101         | Alice (DUPLICATE!)
102         | Bob
103         | Charlie
```

**Write queries to:**
1. Check total revenue before join
2. Check total revenue after join
3. Find which customer_ids have duplicates

**Your Solution:**
```sql
-- Query 1: Total revenue before join
-- Query 2: Total revenue after join
-- Query 3: Find duplicate customer IDs
```

**✓ Solution:**
```sql
-- Query 1: Revenue before join
SELECT SUM(revenue) as total_revenue
FROM orders;
-- Expected: 1000

-- Query 2: Revenue after join
SELECT SUM(o.revenue) as total_revenue
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id;
-- Expected: 1000, but got 1200 (PROBLEM!)

-- Query 3: Find duplicate customer IDs
SELECT 
    customer_id,
    COUNT(*) as count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- Result: customer_id 101 appears 2 times
```

**Why revenue is wrong:**
- Orders for customer 101 total 300.
- But customer 101 appears twice in the customers table.
- So when joined, each order for 101 matches twice: 300 × 2 = 600.
- Total becomes 600 + 400 + 300 = 1300... Actually, let me recalculate:
  - Order 1 (rev 300) matches with customers row 1 (101) → +300
  - Order 1 (rev 300) matches with customers row 2 (101) → +300
  - Order 2 (rev 400) matches with customers row 3 (102) → +400
  - Order 3 (rev 300) matches with customers row 4 (103) → +300
  - **Total: 1300**

If you see 1200, it might mean one of the orders didn't match. But the principle is the same: **check for duplicates in the joined table.**

---

## Exercise 8: Multiple JOINs
**Problem:** Show each order with customer name, product name, and amount. Sort by order_id.

**Tables:**
```
orders:
order_id | customer_id | product_id | amount
1        | 101         | 201        | 50
2        | 102         | 202        | 75

customers:
customer_id | name
101         | Alice
102         | Bob

products:
product_id | product_name
201        | Widget
202        | Gadget
```

**Grain:** One row = one order with customer and product details.

**Your Solution:**
```sql
-- Write your query here
```

**✓ Solution:**
```sql
SELECT 
    o.order_id,
    c.name AS customer_name,
    p.product_name,
    o.amount
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
INNER JOIN products p
    ON o.product_id = p.product_id
ORDER BY o.order_id;
```

**Expected Output:**
```
order_id | customer_name | product_name | amount
1        | Alice         | Widget       | 50
2        | Bob           | Gadget       | 75
```

**Why this works:**
- First JOIN adds customer names (orders → customers).
- Second JOIN adds product names (previous result → products).
- Grain: one row per order (assuming customer and product IDs are unique).
- Always check: Does each order have exactly one customer? One product? If not, cardinality explodes.

---

## Quick Reference: Join Decision Tree

```
Do you want...

1. Only matching rows from both tables?
   → Use INNER JOIN

2. All rows from the left table, plus matches from right?
   → Use LEFT JOIN

3. All rows from the left, and you want to find non-matches?
   → Use LEFT JOIN + WHERE right_table.key IS NULL

4. Join a table to itself (hierarchical data)?
   → Use self-join with different aliases

5. Multiple tables?
   → Stack INNER or LEFT JOINs one after another
```

---

## Common Mistakes & Fixes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Duplicate keys on right table | Row count explodes | Check for duplicates with GROUP BY HAVING COUNT(*) > 1 |
| NULL in join key | Rows disappear in INNER JOIN | Check for NULLs before joining |
| Wrong join type | Missing data or unexpected NULLs | Use LEFT JOIN if you want all left rows |
| Not checking cardinality | Wrong totals (revenue, count) | Count rows before and after join |
| Joining on wrong column | Silent data mismatches | Verify join keys are correct (e.g., customer_id, not name) |
