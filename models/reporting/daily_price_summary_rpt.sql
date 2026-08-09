{{ 
    config(
        materialized='table'
) }}

-- Daily average, minimum and maximum price by fuel type and brand.

select
    d.price_date,
    d.year_month,
    ft.fueltype_name,
    ft.product_category,
    st.brand,
    count(distinct st.station_key)          as station_count,
    round(avg(f.price_per_litre_aud), 3)    as avg_price,
    min(f.price_per_litre_aud)              as lowest_price,
    max(f.price_per_litre_aud)              as highest_price
from {{ ref('fct_fuel_price') }} f
join {{ ref('dim_date') }}      d  on f.date_key    = d.date_key
join {{ ref('dim_fuel_type') }} ft on f.fueltype_key = ft.fueltype_key
join {{ ref('dim_station') }}   st on f.station_key  = st.station_key
group by 1, 2, 3, 4, 5
