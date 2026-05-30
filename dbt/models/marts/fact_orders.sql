{{ config(
    materialized='incremental',
    unique_key='order_surrogate_key',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
) }}

select
    {{ generate_surrogate_key(["orders.order_natural_key"]) }} as order_surrogate_key,
    orders.order_natural_key,
    orders.order_date,
    dates.date_key,
    customers.customer_surrogate_key,
    products.product_key,
    orders.quantity,
    orders.unit_price,
    orders.discount_pct,
    orders.discount_amount,
    orders.final_amount,
    orders.is_discounted,
    orders.order_status,
    orders.payment_method,
    orders.ingested_at
from {{ ref('int_order_items_enriched') }} as orders
left join {{ ref('dim_date') }} as dates
    on orders.order_date = dates.full_date
left join {{ ref('dim_customer') }} as customers
    on orders.customer_natural_key = customers.customer_natural_key
    and customers.is_current = true
left join {{ ref('dim_product') }} as products
    on orders.product_id = products.product_key

{% if is_incremental() %}
where orders.order_date > (select max(order_date) from {{ this }})
{% endif %}
