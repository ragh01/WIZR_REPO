/*
  Station & product (fuel-type) coverage by brand. Answers
  "how many stations does each brand have, and how many fuel
  types do they typically stock" — a coverage/completeness view.
*/
select
    st.brand,
    count(distinct st.station_key)          as station_count,
    count(distinct ft.fueltype_key)         as fuel_types_offered,
    round(avg(f.price_per_litre_aud), 3)   as avg_price
from {{ ref('fct_fuel_price') }} f
join {{ ref('dim_station') }}   st on f.station_key  = st.station_key
join {{ ref('dim_fuel_type') }} ft on f.fueltype_key = ft.fueltype_key
group by 1
