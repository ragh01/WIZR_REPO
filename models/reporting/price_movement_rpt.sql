{{ config(
    materialized='table'
) }}

-- Calculates day-over-day average price movement by fuel type.

with daily as (
    select
        d.price_date,
        ft.fueltype_name,
        round(avg(f.price_per_litre_aud), 3) as avg_price
    from {{ ref('fct_fuel_price') }} f
    join {{ ref('dim_date') }} d
        on f.date_key = d.date_key
    join {{ ref('dim_fuel_type') }} ft
        on f.fueltype_key = ft.fueltype_key
    group by 1, 2
),

movement as (
    select
        price_date,
        fueltype_name,
        avg_price,
        lag(avg_price) over (
            partition by fueltype_name
            order by price_date
        ) as prev_avg_price
    from daily
)

select
    price_date,
    fueltype_name,
    avg_price,
    prev_avg_price,
    round(
        avg_price - prev_avg_price,
        3
    ) as price_movement,
    round(
        (avg_price - prev_avg_price)
        / nullif(prev_avg_price, 0) * 100,
        2
    ) as price_movement_pct
from movement