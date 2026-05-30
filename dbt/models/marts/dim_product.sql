{{ config(
    materialized='table',
    tags=['dimension', 'scd1'],
    meta={'scd_type': 'SCD1'}
) }}

-- Small SCD Type 1 dimension; a full table rebuild is acceptable.
select
    product_key,
    'SCD1' as scd_type,
    title as product_title,
    category as product_category,
    price as current_price,
    rating_rate,
    rating_count,
    current_date as effective_date
from {{ ref('stg_products') }}
