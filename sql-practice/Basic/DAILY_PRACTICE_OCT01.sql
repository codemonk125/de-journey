-- Week 2 Daily Practice: October 1, 2026
-- SQL fundamentals: GROUP BY, COUNT DISTINCT, aggregations, filtering
-- Grain reasoning for every query below

-- ============================================================================
-- PROBLEM 1: Cities With Completed Trades
-- ============================================================================
-- Robinhood trading system
-- Find: Top 3 cities with highest number of completed trade orders
-- GRAIN: One row = one city (aggregated across all trades)

SELECT
    users.city,
    COUNT(trades.order_id) AS total_orders
FROM trades
JOIN users ON trades.user_id = users.user_id
WHERE trades.status = 'completed'  -- filter for completed only
GROUP BY users.city
ORDER BY total_orders DESC
LIMIT 3;

-- Concepts applied:
-- - JOIN: Connect trades to users to get city info
-- - GROUP BY: Aggregate trade count per city
-- - COUNT(trades.order_id): Count completed orders (non-null IDs)
-- - ORDER BY DESC: Highest first
-- - LIMIT 3: Top 3 only
-- - Grain check: Each row = one city with its total completed orders

-- ============================================================================
-- PROBLEM 2: Unique Products per Category
-- ============================================================================
-- Amazon product spend data
-- Find: Number of UNIQUE products in each category
-- GRAIN: One row = one category (with distinct product count)

SELECT
    category,
    COUNT(DISTINCT product_id) AS unique_products
FROM product_spend
GROUP BY category
ORDER BY unique_products DESC;

-- Concepts applied:
-- - COUNT(DISTINCT column): Count unique values only
-- - GROUP BY: Aggregate per category
-- - Why DISTINCT?: Without it, would count product multiple times if it appears
--   in multiple rows (e.g., same product bought by different customers)
-- - Grain check: Each row = one category with its count of distinct products

-- Interview insight: "COUNT DISTINCT filters duplicates before counting"

-- ============================================================================
-- PROBLEM 3: Credit Card Issuance Disparity
-- ============================================================================
-- JPMorgan Chase monthly card issuance data
-- Find: For each card, difference between max and min monthly issuance
-- Show largest disparities first
-- GRAIN: One row = one credit card (with max-min spread)

SELECT
    card_name,
    MAX(issued_amount) - MIN(issued_amount) AS disparity
FROM monthly_cards_issued
GROUP BY card_name
ORDER BY disparity DESC;

-- Concepts applied:
-- - MAX() and MIN() aggregate functions: Find highest and lowest in group
-- - Arithmetic on aggregates: max_value - min_value
-- - GROUP BY: Calculate per card
-- - ORDER BY DESC: Largest disparity first
-- - Grain check: Each row = one card with its issuance spread

-- Real-world: This tells JPMorgan which cards have seasonal or volatile issuance

-- ============================================================================
-- PROBLEM 4: "Big-Mover Month" Stocks
-- ============================================================================
-- Stock price data
-- Big-mover month = stock closes up or down >10% from open
-- Find: Count of big-mover months per ticker
-- GRAIN: One row = one ticker (with count of big-mover months)

SELECT
    ticker,
    COUNT(*) AS big_mover_months
FROM stock_prices
WHERE (close - open) / open > 0.10
   OR (close - open) / open < -0.10
GROUP BY ticker
ORDER BY big_mover_months DESC;

-- Concepts applied:
-- - WHERE with calculation: Filter based on percentage change
-- - (close - open) / open: Percentage change formula
-- - OR: Include both up moves (>10%) and down moves (<-10%)
-- - COUNT(*): Count rows matching the WHERE condition
-- - GROUP BY: Count per ticker
-- - Grain check: Each row = one ticker with its count of big-mover months

-- Production insight: This query finds volatile stocks — useful for risk analysis

-- ============================================================================
-- LEARNING SUMMARY FOR TODAY
-- ============================================================================
--
-- ✅ Topics mastered:
// 1. JOIN + GROUP BY: Connect two tables, aggregate by column
// 2. COUNT(DISTINCT): Count unique values, filter duplicates
// 3. Aggregate functions: MAX(), MIN(), COUNT()
// 4. Arithmetic on aggregates: max - min, (close - open) / open
// 5. WHERE filtering: Apply logic before grouping
// 6. ORDER BY: Sort results by metric (DESC for highest first)
// 7. LIMIT: Top N results
// 8. Grain reasoning: Always state what one row represents
//
// ✅ Grain mistakes avoided:
// - Problem 2: WITHOUT COUNT(DISTINCT), would count same product multiple times
// - Problem 3: MAX/MIN must be aggregated per GROUP to get disparity
// - Problem 4: The WHERE filters rows BEFORE GROUP BY (correct order)
//
// ⏳ Next to practice:
// - Multiple JOINs (3+ tables)
// - HAVING clause (filter after grouping)
// - CTEs (WITH clause) for complex queries
// - Subqueries vs JOINs (when to use each)
