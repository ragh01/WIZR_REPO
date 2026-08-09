{{ 
    config(
        materialized='table'
) }}

-- Brand-level station and fuel-type coverage based on price observations.

with latest as (
    select max(price_date) as latest_date
    from {{ ref('fct_fuel_price') }}
)

select
    st.brand,
    count(distinct st.station_key) as station_count,
    count(distinct ft.fueltype_key) as fuel_types_offered,
    round(avg(f.price_per_litre_aud), 3) as avg_price
from {{ ref('fct_fuel_price') }} f
join {{ ref('dim_station') }} st
    on f.station_key = st.station_key
join {{ ref('dim_fuel_type') }} ft
    on f.fueltype_key = ft.fueltype_key
cross join latest
where f.price_date = latest.latest_date
group by st.brand

