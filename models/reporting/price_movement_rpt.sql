/*
  Day-over-day movement in average price, per fuel type. Answers
  "is petrol getting more or less expensive" without the analyst
  writing a window function themselves.
*/
with daily as (
    select
        d.price_date,
        ft.fueltype_name,
        round(avg(f.price_per_litre_aud), 3) as avg_price
    from {{ ref('fct_fuel_price') }} f
    join {{ ref('dim_date') }}      d  on f.date_key    = d.date_key
    join {{ ref('dim_fuel_type') }} ft on f.fueltype_key = ft.fueltype_key
    group by 1, 2
)
select
    price_date,
    fueltype_name,
    avg_price,
    lag(avg_price) over (partition by fueltype_name order by price_date)              as prev_avg_price,
    round(avg_price - lag(avg_price) over (partition by fueltype_name order by price_date), 3) as price_movement
from daily
