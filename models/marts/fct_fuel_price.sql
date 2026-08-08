/*
  FACT — grain: one row per station x fuel type x day.
  Pure NSW star: no source_system column needed (single source),
  no product-mapping join needed (fueltype_code IS the natural key
  into dim_fuel_type — no name reconciliation across sources required).
*/
select
    {{ generate_surrogate_key(['station_code','fueltype_code','price_date']) }} as price_key,
    to_number(to_char(price_date, 'YYYYMMDD'))                as date_key,
    {{ generate_surrogate_key(['station_code']) }}  as station_key,
    {{ generate_surrogate_key(['fueltype_code']) }} as fueltype_key,
    price_date,
    price_cents,
    price_per_litre_aud
from {{ ref('nsw_fuel_data_int') }}
