{{ config(materialized='view') }}

with source_data as (
    select
        product_id,
        trim(title) as title,
        round(price, 2) as price,
        upper(trim(category)) as category,
        description,
        rating_rate,
        rating_count
    from {{ source('raw', 'raw_products') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by product_id
            order by product_id
        ) as row_rank
    from source_data
)

select
    product_id as product_key,
    title,
    price,
    category,
    description,
    rating_rate,
    rating_count,
    current_timestamp() as ingested_at,
    current_timestamp() as dbt_loaded_at
from ranked
where row_rank = 1
