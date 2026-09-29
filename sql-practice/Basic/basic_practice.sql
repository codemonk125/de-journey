-- DataLemur SQL Tutorial: Basic Practice
-- Source: https://datalemur.com/sql-tutorial
-- Solutions are in tutorial order. Marked (verify) = written by me, not pasted by you.

-- 01. SELECT: view all Azure products
SELECT * FROM products;

-- 02. WHERE: 3-star reviews, only user_id and stars
SELECT user_id, stars
FROM reviews
WHERE stars = 3;

-- 03. AND: reviews with 4+ stars, review_id between 2000 and 6000 (exclusive), not user 142
SELECT *
FROM reviews
WHERE stars >= 4
  AND review_id < 6000
  AND review_id > 2000
  AND user_id != 142;

-- 04. BETWEEN: CVS drugs from Biogen/AbbVie/Eli Lilly selling 100,000-105,000 units
SELECT manufacturer, drug, units_sold
FROM pharmacy_sales
WHERE (manufacturer = 'Biogen' OR manufacturer = 'AbbVie' OR manufacturer = 'Eli Lilly')
  AND units_sold BETWEEN 100000 AND 105000;

-- 05. IN: Roche/Bayer/AstraZeneca drugs NOT selling 55,000-550,000 units
SELECT manufacturer, drug, units_sold
FROM pharmacy_sales
WHERE manufacturer IN ('Roche', 'Bayer', 'AstraZeneca')
  AND units_sold NOT BETWEEN 55000 AND 550000;

-- 06. LIKE: customers whose 2nd and 3rd letters are "e"
SELECT *
FROM customers
WHERE customer_name LIKE '_ee%';

-- 07. Combined filters: age 18-22, VIC/TAS/QLD, gender not 'n/a', name starts with A or B
SELECT *
FROM customers
WHERE age BETWEEN 18 AND 22
  AND state IN ('Victoria', 'Tasmania', 'Queensland')
  AND gender != 'n/a'
  AND (customer_name LIKE 'A%' OR customer_name LIKE 'B%');

-- 08. Pharmacy Analytics (Part 1): top 3 most profitable drugs
SELECT
  drug,
  total_sales - cogs AS total_profit
FROM pharmacy_sales
ORDER BY total_profit DESC
LIMIT 3;

-- 09. COUNT: number of rows in pharmacy_sales
SELECT COUNT(*) FROM pharmacy_sales;

-- 10. SUM: total sales of all Pfizer medicines (verify)
SELECT SUM(total_sales) AS total_sales
FROM pharmacy_sales
WHERE manufacturer = 'Pfizer';

-- 11. AVG: average open price for Google stock (verify)
SELECT AVG(open) AS avg_open
FROM stock_prices
WHERE ticker = 'GOOG';

-- 12. MIN: lowest price Microsoft stock opened at (verify)
SELECT MIN(open) AS min_open
FROM stock_prices
WHERE ticker = 'MSFT';

-- 13. MAX: highest price Netflix stock opened at (verify)
SELECT MAX(open) AS max_open
FROM stock_prices
WHERE ticker = 'NFLX';

-- 14. GROUP BY #1: lowest open price per ticker, highest first (verify)
SELECT ticker, MIN(open) AS min
FROM stock_prices
GROUP BY ticker
ORDER BY min DESC;

-- 15. GROUP BY #2: number of candidates per skill, highest first (verify)
SELECT skill, COUNT(candidate_id) AS count
FROM candidates
GROUP BY skill
ORDER BY count DESC;
