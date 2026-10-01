# Index Deep Dive: Notes & Explanations

## Cardinality: The Key Concept

**Cardinality** = number of unique values in a column.

### High Cardinality
- Many unique values: customer_id (~1000 in our dataset), email, product_id
- **Index these** — queries filter out most rows
- Example: "Get all orders by customer 500" → ~50 matches out of 50,000

### Low Cardinality
- Few unique values: status (pending, completed, cancelled), country (195 countries)
- **Don't index these** — most queries return many rows anyway
- Example: "Get all completed orders" → ~10,000 matches out of 50,000
- At that threshold, reading the entire table is faster than index lookup

---

## EXPLAIN ANALYZE: Reading Query Plans

### Without Index
```
Seq Scan on orders_large  (cost=0.00..944.00 rows=48 width=28)
  Filter: (customer_id = 500)
  Execution Time: 3.200 ms
```

**What this means:**
- **Seq Scan** = sequential scan (reads every row)
- **cost=0.00..944.00** = planner's estimated work (0 to 944 units)
- **rows=48** = planner estimated 48 matches (the WHERE clause will keep 48 rows)
- **Execution Time: 3.200 ms** = actual wall-clock time

### With Index
```
Bitmap Heap Scan on orders_large  (cost=4.35..130.34 rows=48 width=28)
  Recheck Cond: (customer_id = 500)
  Heap Blocks: exact=5
  ->  Bitmap Index Scan on idx_orders_large_customer_id
       Index Cond: (customer_id = 500)
  Execution Time: 0.045 ms
```

**What this means:**
- **Bitmap Index Scan** = uses the index (fast!)
- **Heap Blocks: exact=5** = only fetches 5 disk blocks (vs all blocks for seq scan)
- **Execution Time: 0.045 ms** = ~70x faster!

---

## Why PostgreSQL Sometimes Ignores Indexes

You create an index on `status`, but the query still does a **Seq Scan**:

```sql
CREATE INDEX idx_orders_large_status ON orders_large(status);
EXPLAIN ANALYZE SELECT * FROM orders_large WHERE status = 'completed';
-- Still shows: Seq Scan (not using the index)
```

**Why?**
- The table has 50,000 rows
- ~20% are 'completed' (~10,000 rows)
- PostgreSQL calculates: "I can read all 50,000 rows sequentially faster than jumping through the index to find 10,000 scattered rows"
- So it ignores the index

**Lesson:** Indexes only help when they significantly reduce work. Low-cardinality columns don't.

---

## Composite Indexes

Use when filtering on **multiple columns together**:

```sql
CREATE INDEX idx_orders_customer_date 
ON orders_large(customer_id, order_date);

SELECT * FROM orders_large 
WHERE customer_id = 500 AND order_date >= '2026-03-01';
```

The index is ordered by (customer_id, order_date), so:
1. Find all rows where customer_id = 500 (using index)
2. Among those, filter by order_date (index already sorted by date)
3. Result: single efficient scan

---

## Reading Complex Query Plans (Bottom-Up)

For this query:
```sql
SELECT customer_id, COUNT(*), SUM(order_amount)
FROM orders_large
WHERE order_date >= '2026-01-01'
GROUP BY customer_id
HAVING COUNT(*) > 2
ORDER BY SUM(order_amount) DESC
LIMIT 10;
```

The plan shows:
```
Limit
  ->  Sort
       ->  HashAggregate (with Filter for HAVING)
            ->  Seq Scan (with Filter for WHERE)
```

**Read bottom-up (what happens first):**
1. **Seq Scan + WHERE Filter** → read all rows, keep those with order_date >= '2026-01-01'
2. **HashAggregate** → GROUP BY customer_id, compute COUNT and SUM
3. **Filter (HAVING)** → keep only groups where COUNT(*) > 2
4. **Sort** → order by SUM DESC
5. **Limit** → keep only first 10

---

## Statistics: Why ANALYZE Matters

PostgreSQL uses **statistics** to decide if an index is worth using.

```sql
ANALYZE orders_large;  -- Refresh statistics
```

If statistics are stale:
- Planner makes wrong estimates
- Chooses bad execution plans
- Queries run slower than they should

After `ANALYZE`:
- Planner has fresh row count data
- Better decisions about index usage
- Query executes optimally

---

## Interview Questions & Answers

**Q: "We indexed a column but queries are still slow. What do you do?"**

A: First, I'd use `EXPLAIN ANALYZE` to see what the database is actually doing:
- Is it using the index? (Look for "Index Scan")
- Are statistics stale? (Run `ANALYZE`)
- Is the selectivity too low? (If 50% of rows match, sequential scan might be faster)
- Is there a better index structure? (Composite index? Partial index?)

**Q: "Should we index the country column?"**

A: Probably not. There are only ~195 countries (low cardinality). Most queries would return 1/195th of rows, which is still significant. At that threshold, a sequential scan is often faster than index lookup.

**Q: "How do you choose between single-column and composite indexes?"**

A: Use a composite index if:
1. Your queries filter on multiple columns together
2. Both columns are high-cardinality
3. The combined filter is specific (e.g., customer_id AND order_date narrows down well)

Example: (customer_id, order_date) is good because:
- You often search by both together
- Customer_id is highly selective (~1000 unique)
- Order_date is moderately selective (~365 unique)
- Together: ~50,000 rows / (1000 * 365) ≈ 0.1 rows per combination = very selective

**Q: "How big should indexes be?"**

A: Indexes are overhead. If total index size > 50% of table size, you're indexing too much. Common ratios:
- 1-3x table size = reasonable
- 3-5x = too much, review strategy
- 5x+ = definitely re-evaluate

---

## Key Takeaways

1. **High cardinality** columns (customer_id, email) → index them
2. **Low cardinality** columns (status, country) → usually don't index
3. **Read EXPLAIN ANALYZE** to understand what the database is doing
4. **Run ANALYZE** regularly to keep statistics fresh
5. **Composite indexes** for multi-column WHERE clauses
6. **Test with real data** — a 50-row table behaves different from 50M rows

---

## How This Appears in Real ETL Pipelines

In a data warehouse pipeline:

```python
# Load customer orders into a staging table
INSERT INTO orders_staging SELECT * FROM api_fetch();

# Create indexes for join performance
CREATE INDEX idx_orders_customer_id ON orders_staging(customer_id);

# Join with dimension table
INSERT INTO fact_orders 
SELECT o.*, c.customer_name 
FROM orders_staging o
JOIN dim_customers c ON o.customer_id = c.customer_id;

-- Without the index, this join could take hours on millions of rows.
-- With the index, seconds.

# Clean up
DROP INDEX idx_orders_customer_id;
DROP TABLE orders_staging;
```

The indexing decision directly impacts whether your pipeline finishes in minutes or hours.
