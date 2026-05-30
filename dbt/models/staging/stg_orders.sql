{{ config(materialized='view') }}

with source_data as (
    select
        order_id,
        customer_id,
        product_id,
        quantity,
        unit_price,
        discount_pct,
        cast(order_date as date) as order_date,
        order_status,
        payment_method
    from {{ source('raw', 'raw_orders') }}
    where order_status <> 'Cancelled'
),

ranked as (
    select
        *,
        row_number() over (
            partition by order_id
            order by order_date desc
        ) as row_rank
    from source_data
)

select
    order_id as order_natural_key,
    customer_id as customer_natural_key,
    product_id,
    quantity,
    unit_price,
    discount_pct,
    order_date,
    unit_price * quantity as net_amount,
    unit_price * quantity * discount_pct / 100 as discount_amount,
    (unit_price * quantity) - (unit_price * quantity * discount_pct / 100) as final_amount,
    order_status,
    payment_method,
    current_timestamp() as ingested_at,
    current_timestamp() as dbt_loaded_at
from ranked
where row_rank = 1
