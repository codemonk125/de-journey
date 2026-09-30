# SQL Weeks 2–3: Fundamentals

JOINs, aggregation, and combining tables. These are production fundamentals — every real pipeline uses them.

**Table of Contents**
1. [The JOIN Problem](#1-the-join-problem)
2. [INNER JOIN](#2-inner-join)
3. [LEFT JOIN](#3-left-join)
4. [RIGHT JOIN and FULL OUTER JOIN](#4-right-join-and-full-outer-join)
5. [CROSS JOIN](#5-cross-join)
6. [Self-Joins](#6-self-joins)
7. [GROUP BY Fundamentals](#7-group-by-fundamentals)
8. [HAVING Clause](#8-having-clause)
9. [Aggregate Functions](#9-aggregate-functions)
10. [Subqueries](#10-subqueries)
11. [CTEs (WITH Clause)](#11-ctes-with-clause)
12. [Set Operations (UNION, INTERSECT, EXCEPT)](#12-set-operations-union-intersect-except)
13. [NULL Handling](#13-null-handling)
14. [The Grain Problem](#14-the-grain-problem)
15. [Self-Check Questions](#15-self-check-questions)

---

## 1. The JOIN Problem

**Why JOINs matter:** Real data lives in multiple tables. Orders live in one table, customers in another. To answer "how much did Alice spend?", you must JOIN them.

**The impedance mismatch:** OLTP source systems normalize data across many tables to avoid duplicates. Analytics needs denormalized, wide tables. JOINs bridge that gap.

**Memory this phrase:** *"State the grain before you write the JOIN."*

Example:
```
customers (1 row per customer)
    |
    +-- orders (many rows per customer)
```

If you JOIN without understanding the cardinality (how many orders per customer), one customer row explodes into many, and SUM(revenue) doubles.

---

## 2. INNER JOIN

**What it does:** Returns only rows where BOTH tables have a match.

**Syntax:**
```sql
SELECT c.customer_name, o.order_id, o.total_amount
FROM customers c
INNER JOIN orders o
  ON c.customer_id = o.customer_id;
```

**What one row represents:** One order with its associated customer.

**Grain:** Order-level (because orders is the fact table, not customers).

**When to use:**
- You only care about customers who have orders
- You're confident the join key is unique or well-understood
- You want to filter out unmatched rows

**Production example:**
```sql
-- Revenue per product, only for products that have been ordered
SELECT p.product_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM products p
INNER JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY revenue DESC;
```

**Danger zone — Fan-out:** If the join key is not unique on the right side, rows duplicate:
```
Customer: Alice (1 row)
  matched with
Orders: order_id 100, 101 (2 rows)
  result: Alice appears twice in output, revenue counts double
```

---

## 3. LEFT JOIN

**What it does:** All rows from the LEFT table, plus matches from the RIGHT table. No matches = NULLs.

**Syntax:**
```sql
SELECT c.customer_name, o.order_id, o.total_amount
FROM customers c
LEFT JOIN orders o
  ON c.customer_id = o.customer_id;
```

**What one row represents:** One customer, with their orders (if any).

**Grain:** Customer-level, with NULLs for customers who have no orders.

**When to use:**
- You want all customers, even those with no orders
- You're checking for missing data
- You want to count "customers with orders" vs "customers without orders"

**Production example:**
```sql
-- All customers, even inactive ones, with order count
SELECT c.customer_name, COUNT(o.order_id) AS num_orders
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_name
ORDER BY num_orders DESC;
```

**Key insight:** `COUNT(o.order_id)` returns 0 for customers with no orders (NULL does not count). This is why LEFT JOIN + COUNT is useful for "things that haven't happened yet".

---

## 4. RIGHT JOIN and FULL OUTER JOIN

**RIGHT JOIN:** All rows from the RIGHT table, plus matches from the LEFT.

```sql
SELECT c.customer_name, o.order_id
FROM customers c
RIGHT JOIN orders o
  ON c.customer_id = o.customer_id;
-- Returns all orders, some with customer names, some with NULL
```

**Use case:** Detecting orphaned data (orders with no matching customer).

**FULL OUTER JOIN:** All rows from BOTH tables.

```sql
SELECT c.customer_name, o.order_id
FROM customers c
FULL OUTER JOIN orders o
  ON c.customer_id = o.customer_id;
-- Returns all customers (with NULLs in order columns if no orders)
-- AND all orders (with NULLs in customer columns if orphaned)
```

**Use case:** Data quality checks. Finding mismatches in both directions.

**Production example (data quality):**
```sql
-- Detect orphaned data in both directions
SELECT c.customer_id, o.order_id
FROM customers c
FULL OUTER JOIN orders o ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL OR o.customer_id IS NULL;
-- Returns rows where one side or the other is missing
```

---

## 5. CROSS JOIN

**What it does:** Cartesian product. Every row from the left table matched with every row from the right.

**Syntax:**
```sql
SELECT c.customer_name, p.product_name
FROM customers c
CROSS JOIN products p;
-- Result: 1000 customers × 500 products = 500,000 rows
```

**When to use (rarely):**
- Generating all possible combinations (matrix reporting)
- Materialized dimensions (all customer-product pairs)
- Time series (cross with a calendar table to create a date range)

**Production example:**
```sql
-- All possible customer-product pairs
SELECT c.customer_id, p.product_id
FROM customers c
CROSS JOIN products p;
-- Then LEFT JOIN with actual_orders to find unpurchased combos
```

---

## 6. Self-Joins

**What it is:** A table joined to itself. Used for hierarchical or peer relationships.

**Example: Employee-Manager hierarchy**
```sql
SELECT e.employee_name, m.employee_name AS manager_name
FROM employees e
LEFT JOIN employees m
  ON e.manager_id = m.employee_id;
-- e = employee, m = manager (same employees table)
```

**Example: Related products**
```sql
SELECT p1.product_name, p2.product_name AS related_product
FROM products p1
INNER JOIN product_relationships pr ON p1.product_id = pr.product_id_1
INNER JOIN products p2 ON pr.product_id_2 = p2.product_id;
```

**Key:** Alias the table differently (e.g., `e` and `m`) so SQL knows which instance you're referring to.

---

## 7. GROUP BY Fundamentals

**What it does:** Collapse rows with the same value in a GROUP BY column into one row, and aggregate the rest.

**Syntax:**
```sql
SELECT category, COUNT(*) AS num_products, AVG(price) AS avg_price
FROM products
GROUP BY category;
```

**What one row represents:** One category, with aggregates for all products in that category.

**Rule:** Every column in SELECT must be either:
1. In the GROUP BY clause, OR
2. An aggregate function (COUNT, SUM, AVG, MIN, MAX)

```sql
-- Valid
SELECT category, COUNT(*) FROM products GROUP BY category;

-- Invalid (product_name is not grouped or aggregated)
SELECT category, product_name, COUNT(*) FROM products GROUP BY category;
-- Error: product_name must appear in GROUP BY or be an aggregate function
```

### Group by multiple columns

```sql
SELECT category, supplier, COUNT(*) AS num_products
FROM products
GROUP BY category, supplier;
-- One row per (category, supplier) pair
```

---

## 8. HAVING Clause

**What it does:** Filters aggregates (like WHERE, but for GROUP BY results).

**Syntax:**
```sql
SELECT category, COUNT(*) AS num_products
FROM products
GROUP BY category
HAVING COUNT(*) > 10;  -- Only categories with more than 10 products
```

**Order matters:**
1. WHERE filters rows BEFORE grouping
2. GROUP BY groups
3. HAVING filters groups AFTER aggregation

```sql
SELECT category, COUNT(*) AS num_products
FROM products
WHERE price > 50                    -- Filter rows first
GROUP BY category
HAVING COUNT(*) > 5;                -- Filter groups after
```

**Production example:**
```sql
-- Customers who spent more than $1000 last year
SELECT customer_id, SUM(order_total) AS total_spent
FROM orders
WHERE order_date >= '2024-01-01'
GROUP BY customer_id
HAVING SUM(order_total) > 1000
ORDER BY total_spent DESC;
```

---

## 9. Aggregate Functions

| Function | What it does | NULLs | Example |
|---|---|---|---|
| COUNT(*) | Rows in group | Counts all rows, even those with NULLs | COUNT(*) for group size |
| COUNT(column) | Non-null values in column | Ignores NULLs | COUNT(order_id) |
| SUM(column) | Sum of values | Ignores NULLs, returns NULL if all NULL | SUM(amount) |
| AVG(column) | Average of values | Ignores NULLs | AVG(price) |
| MIN(column) | Smallest value | Ignores NULLs | MIN(date) |
| MAX(column) | Largest value | Ignores NULLs | MAX(salary) |

**Danger: COUNT vs COUNT(column)**

```sql
SELECT category, COUNT(*), COUNT(discount)
FROM products
GROUP BY category;

-- If some products have NULL discount:
-- COUNT(*) returns 50 (all rows)
-- COUNT(discount) returns 45 (non-null only)
```

---

## 10. Subqueries

**What it is:** A query inside another query. Returns a result set that feeds into the outer query.

### Subquery in WHERE

```sql
-- Find customers who spent more than the average
SELECT customer_name
FROM customers
WHERE customer_id IN (
  SELECT customer_id
  FROM orders
  GROUP BY customer_id
  HAVING SUM(order_total) > (
    SELECT AVG(total_spent)
    FROM (
      SELECT customer_id, SUM(order_total) AS total_spent
      FROM orders
      GROUP BY customer_id
    )
  )
);
```

**Readability:** Subqueries are powerful but nesting gets confusing fast. Use CTEs (next section) for clarity.

### Subquery in FROM

```sql
SELECT category, avg_price
FROM (
  SELECT category, AVG(price) AS avg_price
  FROM products
  GROUP BY category
) AS category_stats
WHERE avg_price > 100;
```

---

## 11. CTEs (WITH Clause)

**What it is:** A temporary named result set that makes complex queries readable.

**Syntax:**
```sql
WITH category_stats AS (
  SELECT category, AVG(price) AS avg_price, COUNT(*) AS num_products
  FROM products
  GROUP BY category
)
SELECT category, avg_price, num_products
FROM category_stats
WHERE avg_price > 100
ORDER BY avg_price DESC;
```

**Why CTEs are better than subqueries:**
- More readable: name each step
- Reusable: reference the CTE multiple times
- Testable: each step can be verified independently

**Multiple CTEs:**
```sql
WITH customer_totals AS (
  SELECT customer_id, SUM(order_total) AS total_spent
  FROM orders
  GROUP BY customer_id
),
top_customers AS (
  SELECT customer_id, total_spent
  FROM customer_totals
  WHERE total_spent > 5000
)
SELECT c.customer_name, tc.total_spent
FROM customers c
INNER JOIN top_customers tc ON c.customer_id = tc.customer_id
ORDER BY tc.total_spent DESC;
```

---

## 12. Set Operations (UNION, INTERSECT, EXCEPT)

**What they do:** Combine results from multiple queries.

### UNION

Combines results from two queries, removes duplicates.

```sql
SELECT customer_name FROM customers WHERE country = 'USA'
UNION
SELECT customer_name FROM customers WHERE country = 'Canada';
```

**UNION ALL:** Keeps duplicates (faster, because no deduplication).

```sql
SELECT order_id FROM completed_orders
UNION ALL
SELECT order_id FROM archived_orders;
```

### INTERSECT

Returns rows that appear in BOTH queries.

```sql
SELECT customer_id FROM customers_who_ordered_product_A
INTERSECT
SELECT customer_id FROM customers_who_ordered_product_B;
-- Returns customers who ordered BOTH A and B
```

### EXCEPT

Returns rows from the first query that do NOT appear in the second.

```sql
SELECT customer_id FROM all_customers
EXCEPT
SELECT customer_id FROM customers_who_ordered;
-- Returns customers who have never ordered
```

---

## 13. NULL Handling

**The NULL truth:**
- NULL is "unknown", not "zero" or "empty string"
- NULL + anything = NULL
- NULL = NULL returns NULL (not TRUE)

### COALESCE

Returns the first non-null value.

```sql
SELECT COALESCE(discount, 0) AS discount
FROM products;
-- If discount is NULL, treat as 0
```

### NULLIF

Returns NULL if two values are equal, otherwise the first value.

```sql
SELECT NULLIF(new_price, old_price) AS price_change
FROM products;
-- If price didn't change, show NULL; otherwise show new price
```

### IS NULL / IS NOT NULL

```sql
SELECT customer_name
FROM customers
WHERE phone_number IS NULL;
-- Find customers without a phone number
```

**Production habit:** Always specify NULL handling in aggregates.

```sql
-- Good: explicit
SELECT COALESCE(SUM(amount), 0) FROM orders WHERE status = 'cancelled';

-- Risky: implicit
SELECT SUM(amount) FROM orders WHERE status = 'cancelled';
-- Returns NULL if no rows match, which can break downstream logic
```

---

## 14. The Grain Problem

**Grain** = what one row represents. Stating it is THE most important habit in SQL.

### Grain without JOINs

```sql
SELECT customer_id, SUM(order_total)
FROM orders
GROUP BY customer_id;
-- Grain: One customer, with their total spending
```

### Grain with JOINs (the danger zone)

```sql
-- AMBIGUOUS grain
SELECT o.customer_id, SUM(oi.quantity)
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.customer_id;
-- Is this quantity per order, or per customer?
-- If one order has 10 items, SUM counts all 10 for the customer
```

**How to think about grain:**

1. **Start with the fact table:** What grain is orders? (one row per order)
2. **JOIN a dimension:** What does joining customers add? (context, no change to grain)
3. **GROUP BY:** What grain are you producing? (one row per what?)

```sql
-- CLEAR grain statement
SELECT 
  c.customer_id,
  c.customer_name,
  COUNT(DISTINCT o.order_id) AS num_orders,           -- per customer
  SUM(oi.quantity) AS total_quantity_ordered,          -- summed across all items
  AVG(oi.unit_price) AS avg_unit_price
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.customer_name;
-- Grain: One row per customer, with aggregates across all their orders and items
```

**The fan-out problem:**

```
customers: 3 rows
  |
  +-- orders: 5 rows (3 customers, some with multiple orders)
        |
        +-- order_items: 12 rows (some orders have multiple items)

If you SUM(quantity) without GROUP BY, you count items multiple times.
If you GROUP BY customer without COUNT(DISTINCT order_id), 
  you might count the same order for each of its items.

Always ask: "Will the dimension table cause duplication?"
Answer: Use COUNT(DISTINCT key) or be very careful with aggregates.
```

---

## 15. Self-Check Questions

Try answering before expanding.

1. **What's the difference between INNER JOIN and LEFT JOIN? When would you use each?**

<details>
<summary>Answer</summary>

INNER JOIN returns only rows where both tables match. LEFT JOIN returns all rows from the left table, with NULLs where the right table has no match.

- Use INNER JOIN when you only care about matched records (e.g., customers with orders).
- Use LEFT JOIN when you want all records from the left table, even unmatched ones (e.g., all customers, to count those with and without orders).
</details>

2. **State the grain of this query:**
```sql
SELECT customer_id, COUNT(*) as num_orders, SUM(amount) as total_spent
FROM orders
GROUP BY customer_id;
```

<details>
<summary>Answer</summary>

One row per customer, with the count of their orders and their total spending.
</details>

3. **You have a customers table (1000 rows) and an orders table (10,000 rows). You want to find all customers, including those who have never ordered. Which JOIN type?**

<details>
<summary>Answer</summary>

LEFT JOIN. Customers on the left, orders on the right. This returns all 1000 customers, with NULLs for those who have no orders.
</details>

4. **What's wrong with this query, and how do you fix it?**
```sql
SELECT customer_id, product_name, SUM(amount)
FROM orders
GROUP BY customer_id;
```

<details>
<summary>Answer</summary>

`product_name` is not in the GROUP BY clause and is not an aggregate function. Fix:
```sql
SELECT customer_id, product_name, SUM(amount)
FROM orders
GROUP BY customer_id, product_name;
```
Now you get one row per (customer, product) pair.
</details>

5. **Explain the difference between COUNT(*) and COUNT(column_name).**

<details>
<summary>Answer</summary>

COUNT(*) counts all rows, including those with NULLs in any column. COUNT(column_name) counts only non-null values in that column. If a group has 10 rows but 2 have NULL in the column, COUNT(*) = 10 but COUNT(column_name) = 8.
</details>

6. **Write a CTE-based query to find the top 3 product categories by total revenue.**

<details>
<summary>Answer</summary>

```sql
WITH category_revenue AS (
  SELECT p.category, SUM(oi.quantity * oi.unit_price) AS total_revenue
  FROM products p
  INNER JOIN order_items oi ON p.product_id = oi.product_id
  GROUP BY p.category
)
SELECT category, total_revenue
FROM category_revenue
ORDER BY total_revenue DESC
LIMIT 3;
```
</details>

---

## Key Takeaways

1. **Grain is everything.** State it before you write the JOIN.
2. **JOINs cause fan-out.** Understand which table drives the grain.
3. **NULL is not zero.** Handle it explicitly with COALESCE.
4. **GROUP BY requires discipline.** Every column must be grouped or aggregated.
5. **Production queries are CTEs, not subqueries.** Readability matters.
6. **Always use COUNT(DISTINCT key)** when joining fact and dimension tables, to avoid counting rows multiple times.

---

## Next Steps

- Solve 5–10 more DataLemur problems focusing on JOINs and GROUP BY
- Build a small project: customers + orders + order_items, write 5 queries answering business questions
- Practice stating grain out loud for every query
- Week 4: Window functions, advanced SQL patterns
