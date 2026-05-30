{% snapshot dim_customer_snapshot %}

{{
  config(
    target_schema='snapshots',
    unique_key='customer_natural_key',
    strategy='check',
    check_cols=['email', 'city', 'customer_tier', 'phone']
  )
}}

SELECT
  customer_natural_key,
  full_name,
  email,
  phone,
  city,
  state,
  country,
  customer_tier,
  tier_rank,
  ingested_at
FROM {{ ref('stg_customers') }}

{% endsnapshot %}
