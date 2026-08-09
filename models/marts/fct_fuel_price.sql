{{ config(
    materialized='incremental',
    unique_key='price_key'
) }}

-- Grain: one row per station, fuel type and day.
select
    {{ generate_surrogate_key(['station_code','fuel_type','price_date']) }} as price_key,
    to_number(to_char(price_date, 'YYYYMMDD'))                as date_key,
    station_code,
    {{ generate_surrogate_key(['station_code']) }}  as station_key,
    {{ generate_surrogate_key(['fuel_type']) }} as fueltype_key,
    price_date,
    price_per_litre_aud
from {{ ref('nsw_fuel_data_int') }}


{% if is_incremental() %}

where price_date >= dateadd(day, -2, current_date())

{% endif %}