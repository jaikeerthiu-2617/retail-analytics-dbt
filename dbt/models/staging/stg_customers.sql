{{ config(materialized='view') }}

with source_data as (
    select
        customer_id,
        first_name,
        last_name,
        email,
        phone,
        city,
        state,
        country,
        customer_tier,
        signup_date
    from {{ source('raw', 'raw_customers') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by signup_date desc, email asc
        ) as row_rank
    from source_data
)

select
    customer_id as customer_natural_key,
    trim(first_name) || ' ' || trim(last_name) as full_name,
    lower(trim(email)) as email,
    phone,
    trim(city) as city,
    trim(state) as state,
    trim(country) as country,
    customer_tier,
    case customer_tier
        when 'Bronze' then 1
        when 'Silver' then 2
        when 'Gold' then 3
        else 1
    end as tier_rank,
    signup_date,
    current_timestamp() as ingested_at,
    current_timestamp() as dbt_loaded_at
from ranked
where row_rank = 1
