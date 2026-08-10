{{ 
    config(
        materialized='table'
) }}

-- Station dimension enriched with simulated ABR brand-level matching.
with stations as (
    select
        station_code,
        station_name,
        brand,
        address,
        latitude,
        longitude
    from {{ ref('nsw_stations_int') }}
),

abr as (
    select *
    from {{ ref('station_abr_int') }}
)

select
    {{ generate_surrogate_key(['stations.station_code']) }} as station_key,
    stations.station_code,
    stations.station_name,
    stations.brand,
    stations.address,
    stations.latitude,
    stations.longitude,
    abr.abn,
    abr.abr_entity_name,
    abr.abr_entity_type,
    abr.abr_match_confidence,
    abr.abr_match_method,
    abr.abr_is_verified_via_live_abr_api
from stations
left join abr
    on stations.station_code = abr.station_code