-- DataLemur SQL Practice Problems - SOLVED
-- These are real interview-style problems from DataLemur
-- Date started: 2026-09-29
-- Status: 13 problems solved

-- ============================================================
-- PROBLEM 1: Customer Name Pattern (LIKE with wildcards)
-- ============================================================
-- Question: Find all customers whose first name starts with "F"
-- and the last letter in their last name is "ck".
-- Table: 1000 customer records from Australian small business

SELECT *
FROM customers
WHERE customer_name LIKE 'F%ck';


-- ============================================================
-- PROBLEM 2: Top 3 Most Profitable Drugs
-- ============================================================
-- Question: Find the top 3 most profitable drugs sold,
-- and how much profit they made.
-- Assume no ties in profits. Display from highest to lowest.
-- Table: pharmacy_sales

SELECT drug,
       total_sales - cogs AS total_profit
FROM pharmacy_sales
ORDER BY total_profit DESC
LIMIT 3;


-- ============================================================
-- PROBLEM 3: Manufacturer Losses Analysis
-- ============================================================
-- Question: Identify the manufacturers associated with drugs
-- that resulted in losses. Output manufacturer name,
-- number of drugs with losses, and total losses (absolute value).
-- Sort by highest losses first.
-- Table: pharmacy_sales

SELECT manufacturer,
       COUNT(product_id) AS drug_count,
       SUM(cogs - total_sales) AS total_loss
FROM pharmacy_sales
WHERE cogs > total_sales
GROUP BY manufacturer
ORDER BY total_loss DESC;


-- ============================================================
-- PROBLEM 4: Customer Name Pattern - "ee" in position 2-3
-- ============================================================
-- Question: Find all customers where the 2nd and 3rd letter
-- in their name is "ee"
-- Table: 1000 customer records from Australian small business

SELECT *
FROM customers
WHERE customer_name LIKE '_ee%';


-- ============================================================
-- PROBLEM 5: Complex Customer Filtering
-- ============================================================
-- Question: Find all customers who are:
--   - Between ages 18-22 (inclusive)
--   - Live in Victoria, Tasmania, or Queensland
--   - Gender is not 'n/a'
--   - Name starts with 'A' or 'B'
-- Table: 1000 customer records from Australian small business

SELECT *
FROM customers
WHERE age BETWEEN 18 AND 22
  AND state IN ('Victoria', 'Tasmania', 'Queensland')
  AND gender != 'n/a'
  AND (customer_name LIKE 'A%' OR customer_name LIKE 'B%');


-- ============================================================
-- PROBLEM 6: Row Count Aggregation
-- ============================================================
-- Question: Output the number of rows in the pharmacy_sales table.
-- Table: pharmacy_sales

SELECT COUNT(product_id)
FROM pharmacy_sales;


-- ============================================================
-- PROBLEM 7: Pfizer Drugs Analysis
-- ============================================================
-- Question: Output the total number of drugs manufactured by Pfizer,
-- and the total sales for all Pfizer drugs.
-- Scenario: Data Analyst at CVS Pharmacy
-- Table: pharmacy_sales

SELECT COUNT(drug) AS drug_count,
       SUM(total_sales) AS total_sales
FROM pharmacy_sales
WHERE manufacturer = 'Pfizer';


-- ============================================================
-- PROBLEM 8: Average Opening Price
-- ============================================================
-- Question: Find the average open price for Google stock
-- (ticker symbol 'GOOG').
-- Table: stock_prices

SELECT AVG(open)
FROM stock_prices
WHERE ticker = 'GOOG';


-- ============================================================
-- PROBLEM 9: FAANG Lowest Opening Prices
-- ============================================================
-- Question: For every FAANG stock, find the lowest price
-- each stock ever opened at.
-- Sort results by price in descending order.
-- Table: stock_prices

SELECT ticker,
       MIN(open) AS min_open
FROM stock_prices
GROUP BY ticker
ORDER BY min_open DESC;


-- ============================================================
-- PROBLEM 10: Candidates Per Skill
-- ============================================================
-- Question: How many candidates possess each different skill?
-- Sort answers by count of candidates, from highest to lowest.
-- Table: candidates

SELECT skill,
       COUNT(candidate_id) AS count
FROM candidates
GROUP BY skill
ORDER BY count DESC;


-- ============================================================
-- PROBLEM 11: FAANG Stocks with High Opening Prices (HAVING)
-- ============================================================
-- Question: Find all FAANG stocks whose open share price
-- was always greater than $100.
-- Technique: GROUP BY with HAVING clause
-- Table: stock_prices

SELECT ticker,
       MIN(open) AS min_open
FROM stock_prices
GROUP BY ticker
HAVING MIN(open) > 100;


-- ============================================================
-- PROBLEM 12: Candidates with Multiple Skills (HAVING)
-- ============================================================
-- Question: List candidate IDs of candidates who have
-- more than 2 technical skills.
-- Technique: GROUP BY with HAVING clause
-- Table: candidates

SELECT candidate_id
FROM candidates
GROUP BY candidate_id
HAVING COUNT(skill) > 2;


-- ============================================================
-- PROBLEM 13: Candidates with All Required Skills
-- ============================================================
-- Question: Find candidates proficient in Python, Tableau,
-- and PostgreSQL (all 3 required).
-- Sort output by candidate ID in ascending order.
-- Scenario: Data Science job posting
-- Table: candidates
-- Technique: GROUP BY with HAVING COUNT(DISTINCT skill) = 3

SELECT candidate_id
FROM candidates
WHERE skill IN ('Python', 'Tableau', 'PostgreSQL')
GROUP BY candidate_id
HAVING COUNT(DISTINCT skill) = 3
ORDER BY candidate_id ASC;


-- ============================================================
-- PROGRESS NOTES
-- ============================================================
-- Concepts covered:
-- ✅ LIKE wildcards (%, _)
-- ✅ WHERE filtering (=, !=, BETWEEN, IN)
-- ✅ AND/OR logic
-- ✅ Arithmetic (total_sales - cogs)
-- ✅ ORDER BY (ASC, DESC)
-- ✅ LIMIT
-- ✅ COUNT()
-- ✅ SUM()
-- ✅ AVG()
-- ✅ MIN()
-- ✅ GROUP BY
-- ✅ HAVING with aggregates
-- ✅ DISTINCT in aggregates
--
-- Next: JOINs, subqueries, CTEs, set operations
