/*
  *** ABR ENRICHMENT IS SIMULATED — see seed_brand_abr for full disclosure ***

  MATCHING APPROACH:
    Station identity in the source is free-text ("Shell Reddy Express Coffs
    Harbour") which is unreliable to fuzzy-match against ABR directly without
    a live API call. Instead we match at BRAND level — NSW's `brand` field is
    a small, closed set (Shell, BP, Ampol, United, 7-Eleven, ...) that maps
    deterministically to each parent company's national ABN.

  CONFIDENCE RULES (simulated demo):
    HIGH   - brand found in seed_brand_abr via exact match -> parent entity ABN.
    LOW    - brand present but resolves to a known "independent/unbranded" bucket.
    UNMATCHED - brand not in the reference at all.

  ASSUMPTION:
    The ABN identifies the BRAND/franchisor, not necessarily the legal entity
    operating that specific site (many stations are independently owned
    franchisees trading under a national brand).

  PRODUCTION APPROACH (not implemented — no live ABR GUID in the timebox):
    For each station, call ABR JSON API `MatchingNames.aspx` with the trading
    name (+ postcode as a disambiguator), take the top-scored result, derive
    confidence from ABR's own relevance score:
        score >= 90        -> HIGH
        70 <= score < 90    -> MEDIUM
        score < 70          -> LOW
        no result           -> UNMATCHED
    This gives a station-level match instead of a brand-level one.
*/

with stations as (
    select distinct station_code, station_name, brand
    from {{ ref('nsw_fuel_data_int') }}
),

abr as (
    select * from {{ ref('seed_brand_abr') }}
)

select
    s.station_code,
    s.station_name,
    s.brand,
    a.abn,
    a.entity_name                                     as abr_entity_name,
    a.entity_type                                      as abr_entity_type,
    coalesce(a.match_confidence, 'UNMATCHED')          as abr_match_confidence,
    coalesce(a.match_method, 'NO_MATCH')               as abr_match_method,
    coalesce(a.is_verified_via_live_abr_api, 'FALSE')  as abr_is_verified_via_live_api
from stations s
left join abr a
    on lower(trim(s.brand)) = lower(trim(a.brand))
