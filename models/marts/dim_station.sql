/*
  Station dimension. NSW gives a REAL station code from the source
  (no constructed key needed), enriched with SIMULATED ABR business
  context at brand level. abr_is_verified_via_live_api = FALSE on every
  row — this enrichment demonstrates the design, not a real lookup.
  See int_stations_abr for matching approach, confidence rules, and
  documented limitations.
*/
with base as (
    select
        station_code,
        station_name,
        brand,
        address,
        latitude,
        longitude
    from {{ ref('nsw_fuel_data_int') }}
    qualify row_number() over (
        partition by station_code order by price_date desc
    ) = 1
)

select
    {{ generate_surrogate_key(['b.station_code']) }} as station_key,
    b.station_code,
    b.station_name,
    b.brand,
    b.address,
    b.latitude,
    b.longitude,
    a.abn,
    a.abr_entity_name,
    a.abr_entity_type,
    a.abr_match_confidence,
    a.abr_match_method,
    a.abr_is_verified_via_live_api
from base b
left join {{ ref('station_abr_int') }} a
    on b.station_code = a.station_code
