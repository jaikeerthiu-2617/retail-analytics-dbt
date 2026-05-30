{{ config(materialized='ephemeral') }}

select
    orders.order_natural_key,
    orders.customer_natural_key,
    orders.product_id,
    orders.quantity,
    orders.unit_price,
    orders.discount_pct,
    orders.order_date,
    orders.net_amount,
    orders.discount_amount,
    orders.final_amount,
    orders.order_status,
    orders.payment_method,
    orders.ingested_at,
    products.title as product_title,
    products.category as product_category,
    products.price as listed_price,
    orders.final_amount - products.price as price_variance,
    orders.discount_pct > 0 as is_discounted,
    extract(year from orders.order_date) as order_year,
    extract(month from orders.order_date) as order_month,
    extract(quarter from orders.order_date) as order_quarter
from {{ ref('stg_orders') }} as orders
left join {{ ref('stg_products') }} as products
    on orders.product_id = products.product_key
