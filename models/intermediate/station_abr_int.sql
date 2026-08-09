{{ 
    config(
        materialized='table'
) }}

-- ABR enrichment is simulated using a brand-level seed mapping.
-- Production implementation would use the ABR API for station-level matching.

with stations as (

    select distinct
        station_code,
        station_name,
        brand
    from {{ ref('nsw_stations_stg') }}

),

abr as (
    select *
    from {{ ref('seed_brand_abr') }}
)

select
    s.station_code,
    s.station_name,
    s.brand,
    a.abn,
    a.entity_name as abr_entity_name,
    a.entity_type as abr_entity_type,
    coalesce(a.match_confidence, 'UNMATCHED') as abr_match_confidence,
    coalesce(a.match_method, 'NO_MATCH') as abr_match_method,
    coalesce(
        a.is_verified_via_live_abr_api,
        'FALSE'
    ) as abr_is_verified_via_live_abr_api
from stations s

left join abr a
    on lower(trim(s.brand)) = lower(trim(a.brand))