-- INDEX DEEP DIVE: Cardinality, Performance, EXPLAIN ANALYZE
-- Executable code only. See INDEX_NOTES.md for explanations.

SET search_path TO week2_learning;

-- ============================================================================
-- PART 1: LARGER TABLE FOR BENCHMARKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS orders_large (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    order_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending'
);

-- Seed 50,000 rows
INSERT INTO orders_large (order_id, customer_id, order_date, order_amount, status)
SELECT
    generate_series(1, 50000) as order_id,
    (1 + (random() * 999)::INT) as customer_id,
    CURRENT_DATE - (random() * 365)::INT as order_date,
    (10 + random() * 5000)::NUMERIC(10,2) as order_amount,
    CASE (random() * 4)::INT
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'completed'
        WHEN 2 THEN 'cancelled'
        WHEN 3 THEN 'shipped'
        ELSE 'delivered'
    END as status;

-- ============================================================================
-- PART 2: CARDINALITY CHECK
-- ============================================================================

SELECT 'customer_id' as column_name, COUNT(DISTINCT customer_id) as unique_values FROM orders_large
UNION ALL
SELECT 'status', COUNT(DISTINCT status) FROM orders_large
UNION ALL
SELECT 'order_date', COUNT(DISTINCT order_date) FROM orders_large
UNION ALL
SELECT 'order_amount', COUNT(DISTINCT order_amount) FROM orders_large;

-- Expected: customer_id ~1000, status ~5, order_date ~365, order_amount ~45000+

-- ============================================================================
-- PART 3: INDEX PERFORMANCE - BEFORE AND AFTER
-- ============================================================================

-- Query 1: NO INDEX (sequential scan - slow)
EXPLAIN ANALYZE
SELECT * FROM orders_large WHERE customer_id = 500;

-- Query 2: WITH INDEX (bitmap scan - fast)
CREATE INDEX idx_orders_large_customer_id ON orders_large(customer_id);

EXPLAIN ANALYZE
SELECT * FROM orders_large WHERE customer_id = 500;

-- Expected: ~70x faster with index (e.g., 3.2ms → 0.045ms)

-- ============================================================================
// PART 4: LOW-CARDINALITY INDEX (NOT helpful)
// ============================================================================

CREATE INDEX idx_orders_large_status ON orders_large(status);

EXPLAIN ANALYZE
SELECT * FROM orders_large WHERE status = 'completed';

// Notice: Still uses SEQ SCAN (PostgreSQL chose not to use the index)
// Why? ~20% of rows match, so reading all rows is faster than index

// ============================================================================
// PART 5: COMPOSITE INDEX
// ============================================================================

CREATE INDEX idx_orders_large_customer_date
ON orders_large(customer_id, order_date);

EXPLAIN ANALYZE
SELECT * FROM orders_large
WHERE customer_id = 500 AND order_date >= '2026-03-01';

// ============================================================================
// PART 6: COMPLEX QUERY PLAN
// ============================================================================

EXPLAIN ANALYZE
SELECT
    customer_id,
    COUNT(*) as order_count,
    SUM(order_amount) as total_amount
FROM orders_large
WHERE order_date >= '2026-01-01'
GROUP BY customer_id
HAVING COUNT(*) > 2
ORDER BY total_amount DESC
LIMIT 10;

// Read bottom-up:
// 1. Seq Scan: filter by order_date
// 2. HashAggregate: GROUP BY customer_id
// 3. Filter: HAVING clause
// 4. Sort: ORDER BY
// 5. Limit: LIMIT 10

// ============================================================================
// PART 7: REFRESH STATISTICS
// ============================================================================

ANALYZE orders_large;

EXPLAIN ANALYZE
SELECT * FROM orders_large WHERE customer_id = 500;

// Statistics now more accurate; better query planning

// ============================================================================
// EXERCISES
// ============================================================================

// EXERCISE 1: Query with HIGH cardinality vs LOW cardinality
EXPLAIN ANALYZE SELECT * FROM orders_large WHERE customer_id = 100;
EXPLAIN ANALYZE SELECT * FROM orders_large WHERE status = 'pending';
// Which is faster? Why?

// EXERCISE 2: Test composite index
EXPLAIN ANALYZE
SELECT * FROM orders_large
WHERE order_date >= '2026-01-01' AND customer_id = 500;

// EXERCISE 3: Index size
SELECT
    pg_size_pretty(pg_total_relation_size('orders_large')) as table_size,
    pg_size_pretty(pg_indexes_size('orders_large')) as indexes_size;
