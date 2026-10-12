# SQL: Window Functions and Latest Records Pattern

Master the most common SQL pattern in data engineering: finding the latest/highest/first row per group.

---

## Problem: Find Inactive Free Users

**Business Requirement**
Find all users who:
- Have a subscription_tier = 'free'
- Have been inactive for more than 30 days
- Inactivity = Current Date − Most Recent Login Date

**Expected Output**
- user_id
- email
- subscription_tier
- last_login_date
- days_inactive
- Sort by highest inactivity first

---

## Learning 1: Break Down the Requirement

Always convert business requirements into SQL steps.

**What we're actually doing**:
1. Find latest login per user
2. Calculate days since that login
3. Filter for free users only
4. Filter for inactivity > 30 days
5. Sort descending by inactivity

**Key insight**: This is a "latest per group" problem. Same pattern appears everywhere:
- Latest order per customer
- Most recent salary per employee
- Newest status per ticket
- First purchase per user

---

## Learning 2: Pattern Recognition

Whenever you see these words, think "latest/highest/first per group":

| Keyword | SQL Pattern |
|---------|-------------|
| Latest, Recent, Newest, Last | MAX() or ROW_NUMBER() |
| Highest, Top | MAX() or ROW_NUMBER() |
| First, Oldest | MIN() or ROW_NUMBER() |
| Most (e.g., most active) | MAX() with aggregation |

---

## Learning 3: Two Approaches

### Approach 1: MAX() — Simple and Sufficient

Use when you **only need the maximum value**:

```sql
SELECT
    user_id,
    MAX(login_date) AS last_login_date
FROM user_logins
GROUP BY user_id;
```

**Pros**:
- Simple, readable, fast
- Works for most analytical queries

**Cons**:
- Can't get other columns from the same row
- Example: You get the latest date but not the IP address from that login

### Approach 2: ROW_NUMBER() — Get Full Rows

Use when you **need the entire latest row**:

```sql
WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY login_date DESC
        ) AS rn
    FROM user_logins
)
SELECT *
FROM ranked
WHERE rn = 1;
```

**Pros**:
- Get all columns from the latest row
- More control over ranking

**Cons**:
- More verbose
- Slightly slower on massive datasets

---

## Learning 4: Window Function Anatomy

```sql
ROW_NUMBER() OVER (
    PARTITION BY user_id
    ORDER BY login_date DESC
) AS rn
```

| Part | Meaning |
|------|---------|
| `PARTITION BY user_id` | Create separate groups for each user |
| `ORDER BY login_date DESC` | Rank by date, newest first |
| `ROW_NUMBER()` | Assign rank 1, 2, 3... |

**Result for user 1**:

| user_id | login_date | rn |
|---------|------------|-----|
| 1 | 2024-04-01 | 1 ← Latest |
| 1 | 2024-03-15 | 2 |
| 1 | 2024-02-10 | 3 |

We keep `WHERE rn = 1` to get only the latest.

---

## Learning 5: Date Arithmetic

PostgreSQL (and most databases) support simple date math:

```sql
DATE '2024-04-10' - DATE '2024-03-01'  -- Returns 40 (days)
```

To calculate days inactive from current date:

```sql
CURRENT_DATE - login_date AS days_inactive
-- or
'2024-04-10'::DATE - login_date AS days_inactive  -- For testing
```

---

## Learning 6: WHERE vs HAVING

Critical distinction:

| Clause | When It Runs | What It Filters |
|--------|-------------|-----------------|
| WHERE | Before GROUP BY | Rows |
| HAVING | After GROUP BY | Groups |

**Performance rule**: Always filter in WHERE when possible (smaller dataset before aggregation).

```sql
-- ✅ CORRECT: Filter before grouping
SELECT
    user_id,
    COUNT(*) AS login_count
FROM user_logins
WHERE user_id IN (SELECT user_id FROM users WHERE subscription_tier = 'free')
GROUP BY user_id;

-- ❌ INEFFICIENT: Filter after grouping
SELECT
    user_id,
    COUNT(*) AS login_count
FROM user_logins
GROUP BY user_id
HAVING ... (check if user is free)  -- Too late, already grouped
```

---

## Learning 7: The Solution

```sql
SELECT
    u.user_id,
    u.email,
    u.subscription_tier,
    MAX(ul.login_date) AS last_login_date,
    '2024-04-10'::DATE - MAX(ul.login_date) AS days_inactive
FROM users u
JOIN user_logins ul
    ON u.user_id = ul.user_id
WHERE u.subscription_tier = 'free'
GROUP BY
    u.user_id,
    u.email,
    u.subscription_tier
HAVING '2024-04-10'::DATE - MAX(ul.login_date) > 30
ORDER BY days_inactive DESC;
```

**Why this works**:

1. `JOIN user_logins`: Get login history for each user
2. `WHERE subscription_tier = 'free'`: Filter free users early (performance)
3. `GROUP BY user_id, ...`: Create one row per user
4. `MAX(ul.login_date)`: Get their latest login
5. `HAVING ... > 30`: Filter groups (after aggregation) for inactivity > 30 days
6. `ORDER BY days_inactive DESC`: Newest to oldest inactivity

---

## Learning 8: The NULL Trap

**Critical edge case**: Users with NO login records.

**Current query uses**: `INNER JOIN`
- Result: Free users who never logged in are **excluded**
- Reason: No matching row in user_logins, so they don't make it to GROUP BY

**Should we include them?**

If yes, use LEFT JOIN and handle NULL:

```sql
SELECT
    u.user_id,
    u.email,
    u.subscription_tier,
    MAX(ul.login_date) AS last_login_date,
    '2024-04-10'::DATE - MAX(ul.login_date) AS days_inactive
FROM users u
LEFT JOIN user_logins ul  -- ← Changed to LEFT JOIN
    ON u.user_id = ul.user_id
WHERE u.subscription_tier = 'free'
GROUP BY u.user_id, u.email, u.subscription_tier
HAVING 
    MAX(ul.login_date) IS NULL  -- ← Include never-logged-in users
    OR '2024-04-10'::DATE - MAX(ul.login_date) > 30
ORDER BY days_inactive DESC;
```

**Why the HAVING change is necessary**:
- If `MAX(ul.login_date)` is NULL (user never logged in), then:
  - `NULL - '2024-04-10'` = `NULL`
  - `NULL > 30` = `NULL` (not TRUE)
  - HAVING treats NULL as FALSE, row is excluded

**Solution**: Explicitly check `IS NULL`.

**Business decision**:
- **INNER JOIN** = "We can only measure inactivity if there's a login date"
- **LEFT JOIN + IS NULL** = "Never logging in = infinitely inactive"

Choose based on your business requirement.

---

## Learning 9: Interview Checklist

When you see "latest/highest/first per group":

- [ ] Identify the grouping column (e.g., user_id)
- [ ] Identify the ranking column (e.g., login_date)
- [ ] Decide: MAX() or ROW_NUMBER()?
- [ ] If MAX(), which GROUP BY columns do I need?
- [ ] If ROW_NUMBER(), will I use WHERE rn = 1?
- [ ] Do I need WHERE (row-level) or HAVING (group-level) filters?
- [ ] Edge case: What about NULLs or missing data?
- [ ] Edge case: What about ties (two logins on same date)?

---

## Learning 10: Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Using INNER JOIN and missing NULL users | Silent data loss | Use LEFT JOIN + IS NULL check |
| Forgetting GROUP BY column | Query errors | Include all non-aggregated columns in GROUP BY |
| Using alias in WHERE | "Column doesn't exist" error | Use HAVING or repeat the expression |
| Using alias in HAVING | May work but not guaranteed | Repeat the expression instead |
| MAX() but need other columns | "Missing from GROUP BY" error | Use ROW_NUMBER() instead |
| Forgetting ORDER BY | Non-deterministic results | Always ORDER BY for consistent output |
| Hardcoded date in production | Results become stale | Use CURRENT_DATE or parameter |

---

## Practice Challenge

**Modify the query to find**:
- Free users inactive > 30 days
- **But also** include users with 0 login records (never logged in)
- Show: user_id, email, last_login_date (NULL if never logged in), days_inactive
- Sort: most inactive first

What changes do you need to make?

---

## Production Considerations

**Hardcoded date for testing**: `'2024-04-10'::DATE`

**For production use**: `CURRENT_DATE`

```sql
-- Test version (reproducible)
'2024-04-10'::DATE - MAX(ul.login_date) AS days_inactive

-- Production version (always current)
CURRENT_DATE - MAX(ul.login_date) AS days_inactive
```

**Index optimization** (if table is large):
```sql
CREATE INDEX idx_user_logins_user_date 
ON user_logins(user_id, login_date DESC);
```

---

## Summary: The "Latest Per Group" Pattern

This pattern is in 80% of real data pipelines:

- **Analytics**: Latest transaction per customer
- **Monitoring**: Most recent error per service
- **Reporting**: Newest order per account
- **Features**: Last login per user (this problem)

Mastering MAX() + GROUP BY and ROW_NUMBER() + PARTITION BY makes you dangerous in interviews and production.

---

*Last updated: 2026-10-12*
