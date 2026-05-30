-- Query 1: Monthly revenue trend with month-over-month growth percentage.
WITH monthly_revenue AS (
  SELECT
    d.year,
    d.month_number,
    d.month_name,
    SUM(f.final_amount) AS total_revenue
  FROM ANALYTICS_DB.MARTS.FACT_ORDERS f
  JOIN ANALYTICS_DB.MARTS.DIM_DATE d
    ON f.date_key = d.date_key
  GROUP BY d.year, d.month_number, d.month_name
),
with_previous AS (
  SELECT
    *,
    LAG(total_revenue) OVER (ORDER BY year, month_number) AS previous_month_revenue
  FROM monthly_revenue
)
SELECT
  year,
  month_number,
  month_name,
  total_revenue,
  ROUND(
    100 * (total_revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0),
    2
  ) AS month_over_month_growth_pct
FROM with_previous
ORDER BY year, month_number;

-- Query 2: Revenue by product category with each category's share of total revenue.
WITH category_revenue AS (
  SELECT
    p.product_category,
    SUM(f.final_amount) AS total_revenue
  FROM ANALYTICS_DB.MARTS.FACT_ORDERS f
  JOIN ANALYTICS_DB.MARTS.DIM_PRODUCT p
    ON f.product_key = p.product_key
  GROUP BY p.product_category
)
SELECT
  product_category,
  total_revenue,
  ROUND(100 * total_revenue / NULLIF(SUM(total_revenue) OVER (), 0), 2) AS pct_of_total_revenue
FROM category_revenue
ORDER BY total_revenue DESC;

-- Query 3: Customer lifetime value for the top 20 current customers.
SELECT
  c.customer_natural_key,
  c.full_name,
  c.customer_tier,
  COUNT(DISTINCT f.order_natural_key) AS order_count,
  SUM(f.final_amount) AS lifetime_value,
  AVG(f.final_amount) AS avg_order_value
FROM ANALYTICS_DB.MARTS.FACT_ORDERS f
JOIN ANALYTICS_DB.MARTS.DIM_CUSTOMER c
  ON f.customer_surrogate_key = c.customer_surrogate_key
WHERE c.is_current = TRUE
GROUP BY c.customer_natural_key, c.full_name, c.customer_tier
ORDER BY lifetime_value DESC
LIMIT 20;

-- Query 4: SCD2 history demo showing customers whose tier changed over time.
SELECT
  old.customer_natural_key,
  old.full_name,
  old.customer_tier AS old_tier,
  current_customer.customer_tier AS new_tier,
  old.dbt_valid_from AS old_valid_from,
  old.dbt_valid_to AS change_date,
  current_customer.dbt_valid_from AS current_valid_from
FROM ANALYTICS_DB.MARTS.DIM_CUSTOMER old
JOIN ANALYTICS_DB.MARTS.DIM_CUSTOMER current_customer
  ON old.customer_natural_key = current_customer.customer_natural_key
WHERE old.is_current = FALSE
  AND current_customer.is_current = TRUE
  AND old.customer_tier <> current_customer.customer_tier
ORDER BY change_date DESC;

-- Query 5: Data quality dashboard with row counts and null percentage for key columns.
SELECT 'RAW_PRODUCTS' AS object_name, 'RAW' AS layer, COUNT(*) AS row_count,
       ROUND(100 * SUM(IFF(product_id IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2) AS key_null_pct
FROM RAW_DB.PUBLIC.RAW_PRODUCTS
UNION ALL
SELECT 'RAW_USERS', 'RAW', COUNT(*),
       ROUND(100 * SUM(IFF(user_id IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM RAW_DB.PUBLIC.RAW_USERS
UNION ALL
SELECT 'RAW_CUSTOMERS', 'RAW', COUNT(*),
       ROUND(100 * SUM(IFF(customer_id IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM RAW_DB.PUBLIC.RAW_CUSTOMERS
UNION ALL
SELECT 'RAW_ORDERS', 'RAW', COUNT(*),
       ROUND(100 * SUM(IFF(order_id IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM RAW_DB.PUBLIC.RAW_ORDERS
UNION ALL
SELECT 'STG_PRODUCTS', 'STAGING', COUNT(*),
       ROUND(100 * SUM(IFF(product_key IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM ANALYTICS_DB.STAGING.STG_PRODUCTS
UNION ALL
SELECT 'STG_CUSTOMERS', 'STAGING', COUNT(*),
       ROUND(100 * SUM(IFF(customer_natural_key IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM ANALYTICS_DB.STAGING.STG_CUSTOMERS
UNION ALL
SELECT 'STG_ORDERS', 'STAGING', COUNT(*),
       ROUND(100 * SUM(IFF(order_natural_key IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM ANALYTICS_DB.STAGING.STG_ORDERS
UNION ALL
SELECT 'DIM_DATE', 'MART', COUNT(*),
       ROUND(100 * SUM(IFF(date_key IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM ANALYTICS_DB.MARTS.DIM_DATE
UNION ALL
SELECT 'DIM_PRODUCT', 'MART', COUNT(*),
       ROUND(100 * SUM(IFF(product_key IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM ANALYTICS_DB.MARTS.DIM_PRODUCT
UNION ALL
SELECT 'DIM_CUSTOMER', 'MART', COUNT(*),
       ROUND(100 * SUM(IFF(customer_surrogate_key IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM ANALYTICS_DB.MARTS.DIM_CUSTOMER
UNION ALL
SELECT 'FACT_ORDERS', 'MART', COUNT(*),
       ROUND(100 * SUM(IFF(order_surrogate_key IS NULL, 1, 0)) / NULLIF(COUNT(*), 0), 2)
FROM ANALYTICS_DB.MARTS.FACT_ORDERS
ORDER BY layer, object_name;
