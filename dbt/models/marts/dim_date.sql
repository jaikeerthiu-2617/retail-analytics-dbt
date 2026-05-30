{{ config(materialized='table') }}

-- Static date dimension. Build once unless the calendar range changes; no full-refresh is needed on normal runs.
with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="to_date('2021-01-01')",
        end_date="to_date('2026-01-01')"
    ) }}
)

select
    to_number(to_char(date_day, 'YYYYMMDD')) as date_key,
    cast(date_day as date) as full_date,
    dayofweekiso(date_day) as day_of_week,
    initcap(trim(to_char(date_day, 'DAY'))) as day_name,
    weekiso(date_day) as week_of_year,
    month(date_day) as month_number,
    initcap(trim(to_char(date_day, 'MONTH'))) as month_name,
    quarter(date_day) as quarter,
    year(date_day) as year,
    dayofweekiso(date_day) in (6, 7) as is_weekend,
    cast(date_day as date) = date_trunc('month', date_day) as is_month_start,
    cast(date_day as date) = last_day(date_day, 'month') as is_month_end
from date_spine
