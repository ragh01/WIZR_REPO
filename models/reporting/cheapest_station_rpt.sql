/*
  "Where's the cheapest fuel right now" — the single query a business
  user is most likely to actually ask for. One row per fuel type,
  showing the lowest current price and which station has it.
*/
with latest as (
    select max(price_date) as latest_date from {{ ref('fct_fuel_price') }}
),
ranked as (
    select
        ft.fueltype_name,
        st.station_name,
        st.brand,
        st.address,
        f.price_per_litre_aud,
        row_number() over (
            partition by ft.fueltype_name order by f.price_per_litre_aud asc
        ) as price_rank
    from {{ ref('fct_fuel_price') }} f
    join {{ ref('dim_fuel_type') }} ft on f.fueltype_key = ft.fueltype_key
    join {{ ref('dim_station') }}   st on f.station_key  = st.station_key
    join {{ ref('dim_date') }}      d  on f.date_key     = d.date_key
    cross join latest
    where d.price_date = latest.latest_date
)
select fueltype_name, station_name, brand, address, price_per_litre_aud
from ranked
where price_rank = 1
