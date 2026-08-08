/*
  Staging (logical Silver — cleaning layer). Joins the NSW price feed to the
  station reference data, casts types, and — deliberately — snapshots an
  INTRADAY feed down to a DAILY grain (one price per station x fuel type x day,
  latest observation that day wins). This is a design choice, not a limitation:
  it makes NSW comparable to WA for daily trend reporting.
*/

with prices as (
    select *,
    {{ cents_to_dollars('price') }} as price_per_litre_aud
    from {{ ref('nsw_prices_stg') }}
),

stations as (
    select *
    from {{ ref('nsw_stations_stg') }}
),

cleaned as (
    select
        p.stationcode::string                                     as station_code,
        upper(trim(p.fueltype))                                   as fueltype_code,
        try_to_number(p.price, 10, 2)                             as price_cents,
        try_to_timestamp(p.lastupdated, 'DD/MM/YYYY HH24:MI:SS')  as price_ts,
        price_per_litre_aud,
        s.brand,
        s.name         as station_name,
        s.address,
        s.latitude                               as latitude,
        s.longitude                              as longitude
    from prices p
    left join stations s
        on p.stationcode::string = s.code::string
    where try_to_number(p.price, 10, 2) > 0
      and try_to_timestamp(p.lastupdated, 'DD/MM/YYYY HH24:MI:SS') is not null
)

select
    *,
    date(price_ts)                as price_date
from cleaned
-- Daily grain: one row per station x fuel type x day (latest price that day wins)
qualify row_number() over (
    partition by station_code, fueltype_code, date(price_ts)
    order by price_ts desc
) = 1
