{{ config(
    materialized='table',
    tags=['dimension', 'scd2'],
    meta={'scd_type': 'SCD2'}
) }}

-- Customer history is handled by the upstream dbt snapshot; this model projects the SCD2 dimension.
select
    {{ generate_surrogate_key(["customer_natural_key", "dbt_valid_from"]) }} as customer_surrogate_key,
    'SCD2' as scd_type,
    customer_natural_key,
    full_name,
    email,
    phone,
    city,
    state,
    country,
    customer_tier,
    tier_rank,
    dbt_valid_from,
    dbt_valid_to,
    dbt_valid_to is null as is_current
from {{ ref('dim_customer_snapshot') }}
